# Repository Examples

Use these examples when adding or refactoring repository contracts in a DDD project.

## Singular Repository

The domain owns both the model and repository contract. A missing singular object is represented by `NotFoundException`.

```php
namespace Example\Domain\LegalOperator;

use Example\Domain\NotFoundException;

interface LegalOperatorRepository
{
    /** @throws NotFoundException */
    public function find(): LegalOperator;
}
```

When lookup criteria are required, pass domain types to the same method without repeating the repository subject:

```php
namespace Example\Domain\Owner;

use Example\Domain\NotFoundException;

interface OwnerRepository
{
    /** @throws NotFoundException */
    public function find(OwnerId $ownerId): Owner;
}
```

## Collection Repository

Use `findAll()` for the complete collection and `findBy(...)` for a criteria-filtered collection. Both return a list and use an empty list when there are no results. For one criteria-matched object, use `findOneBy(...)` with the same `NotFoundException` contract as `find(...)`.

```php
namespace Example\Domain\Inquiry;

interface ForwardingRecipientRepository
{
    /** @return list<ForwardingRecipient> */
    public function findAll(): array;
}
```

If several workflows consume the recipients, keep the shared `ForwardingRecipient` model in the domain instead of creating a frontend-specific `PrivacyPolicyRecipient` copy.

## Direct Doctrine Entity Persistence

For Doctrine-backed API resource writes, read the [worked User endpoint](../../php-api-endpoints/references/user-endpoint.md#entity-and-repository). It shows a domain-owned `UserRepository::saveAndFlush(User $user): User`, a directly attribute-mapped domain `User`, and an infrastructure `DoctrineUserRepository` using `EntityManagerInterface`. Mapping attributes on entities and embedded values are permitted metadata when following this pattern; respect an explicit alternative project mapping policy. Keep ORM APIs out of repository signatures and persistence operations out of domain/application code. Do not add a separate persistence record solely to remove mapping attributes.

## Infrastructure Implementations

Storage details belong to implementation names and constructors, not the domain contract.

```php
namespace Example\Infrastructure\PrivacyPolicy;

use Example\Domain\NotFoundException;
use Example\Domain\PrivacyPolicy\PrivacyPolicyVersion;
use Example\Domain\PrivacyPolicy\PrivacyPolicyVersionRepository;
use RuntimeException;

final class FilePrivacyPolicyVersionRepository implements PrivacyPolicyVersionRepository
{
    public function __construct(private string $filePath)
    {
    }

    public function find(): PrivacyPolicyVersion
    {
        if (!is_file($this->filePath)) {
            throw new NotFoundException('The privacy-policy version was not found.');
        }

        $version = file_get_contents($this->filePath);
        if ($version === false) {
            throw new RuntimeException('The privacy-policy version cannot be read.');
        }

        return new PrivacyPolicyVersion(trim($version));
    }
}
```

When retrieval uses a remote API, keep the domain-facing retrieval contract on the repository and let its infrastructure implementation call a technical client. The client's existing `LegalOperatorResponse` is a transport DTO; an infrastructure factory constructs the domain model from it. The service still receives `LegalOperator` from the repository and uses its own output DTO factory. Keep the client, transport type and transport-to-entity factory in infrastructure so the domain contract does not depend on them.

```php
namespace Example\Infrastructure\LegalOperator;

use Example\Domain\LegalOperator\LegalOperator;
use Example\Domain\LegalOperator\LegalOperatorRepository;

final class RemoteLegalOperatorRepository implements LegalOperatorRepository
{
    public function __construct(
        private LegalOperatorClient $legalOperatorClient,
        private LegalOperatorFactory $legalOperatorFactory,
    )
    {
    }

    public function find(): LegalOperator
    {
        $legalOperatorResponse = $this->legalOperatorClient->fetchLegalOperator();

        return $this->legalOperatorFactory->create($legalOperatorResponse);
    }
}
```

The factory owns the transport-to-entity construction:

```php
namespace Example\Infrastructure\LegalOperator;

use Example\Domain\LegalOperator\LegalOperator;

final class LegalOperatorFactory
{
    public function create(LegalOperatorResponse $legalOperatorResponse): LegalOperator
    {
        return new LegalOperator(
            $legalOperatorResponse->name,
            $legalOperatorResponse->postalAddressLines,
            $legalOperatorResponse->email,
        );
    }
}
```

An empty infrastructure implementation still honors the collection contract:

```php
namespace Example\Infrastructure\Inquiry;

use Example\Domain\Inquiry\ForwardingRecipientRepository;

final class EmptyForwardingRecipientRepository implements ForwardingRecipientRepository
{
    public function findAll(): array
    {
        return [];
    }
}
```

Frontend ViewServices consume domain repository contracts, map domain models into presentation ViewModels, and return the complete page ViewModel. Controllers depend on those services and keep only HTTP input adaptation, rendering, status codes, and response headers:

```php
namespace Example\App\Frontend\PrivacyPolicy;

use Example\Domain\Inquiry\ForwardingRecipientRepository;
use Example\Domain\LegalOperator\LegalOperatorRepository;

final readonly class PrivacyPolicyContactViewModel
{
    public function __construct(
        public string $name,
        public string $protectedEmail,
    ) {
    }
}

final readonly class PrivacyPolicyRecipientViewModel
{
    public function __construct(public PrivacyPolicyContactViewModel $contact)
    {
    }
}

final readonly class PrivacyPolicyContentViewModel
{
    /** @param list<PrivacyPolicyRecipientViewModel> $recipients */
    public function __construct(
        public PrivacyPolicyContactViewModel $operator,
        public array $recipients,
    ) {
    }
}

final readonly class PrivacyPolicyPageViewModel implements PageViewModel
{
    public function __construct(
        public PageMetadataViewModel $metadata,
        public SiteHeaderViewModel $header,
        public PrivacyPolicyContentViewModel $content,
        public LegalNavigationViewModel $legalNavigation,
    ) {
    }

    public function metadata(): PageMetadataViewModel
    {
        return $this->metadata;
    }
}

final class PrivacyPolicyViewService
{
    public function __construct(
        private LegalOperatorRepository $legalOperatorRepository,
        private ForwardingRecipientRepository $forwardingRecipientRepository,
        private PublicEmailProtector $publicEmailProtector,
        private SiteHeaderViewModelFactory $siteHeaderViewModelFactory,
        private LegalNavigationViewModelFactory $legalNavigationViewModelFactory,
    ) {
    }

    public function fetchPage(Locale $locale): PrivacyPolicyPageViewModel
    {
        $metadata = new PageMetadataViewModel($locale, 'Privacy policy');
        $header = $this->siteHeaderViewModelFactory->createForLegalPage(
            $locale,
            'privacy-policy',
        );
        $content = $this->fetchContent();
        $legalNavigation = $this->legalNavigationViewModelFactory->create(
            $locale,
            'privacy-policy',
        );

        return new PrivacyPolicyPageViewModel(
            $metadata,
            $header,
            $content,
            $legalNavigation,
        );
    }

    private function fetchContent(): PrivacyPolicyContentViewModel
    {
        $legalOperator = $this->legalOperatorRepository->find();
        $protectedOperatorEmail = $this->publicEmailProtector->protect($legalOperator->email);
        $operator = new PrivacyPolicyContactViewModel(
            $legalOperator->name,
            $protectedOperatorEmail,
        );
        $recipients = [];

        foreach ($this->forwardingRecipientRepository->findAll() as $recipient) {
            $protectedRecipientEmail = $this->publicEmailProtector->protect($recipient->email);
            $contact = new PrivacyPolicyContactViewModel(
                $recipient->name,
                $protectedRecipientEmail,
            );
            $recipients[] = new PrivacyPolicyRecipientViewModel($contact);
        }

        return new PrivacyPolicyContentViewModel($operator, $recipients);
    }
}

final class PrivacyPolicyController
{
    public function __construct(
        private PhpRenderer $phpRenderer,
        private PrivacyPolicyViewService $privacyPolicyViewService,
    ) {
    }

    public function getPrivacyPolicy(
        ResponseInterface $response,
        string $locale,
    ): ResponseInterface {
        $selectedLocale = Locale::from($locale);
        $page = $this->privacyPolicyViewService->fetchPage($selectedLocale);
        $renderedResponse = $this->phpRenderer->render(
            $response,
            'privacy-policy.php',
            ['page' => $page],
        );

        return $renderedResponse
            ->withHeader('Content-Language', $selectedLocale->value)
            ->withHeader('Content-Type', 'text/html; charset=UTF-8');
    }
}
```

## Incorrect Boundaries

This controller coordinates persistence and exposes repository results to the template:

```php
namespace Example\App\Frontend\PrivacyPolicy;

final class PrivacyPolicyController
{
    public function __construct(
        private LegalOperatorRepository $legalOperatorRepository,
        private ForwardingRecipientRepository $forwardingRecipientRepository,
    ) {
    }

    public function getPrivacyPolicy(
        ServerRequestInterface $request,
        ResponseInterface $response,
    ): ResponseInterface {
        return $this->phpRenderer->render($response, 'privacy-policy.php', [
            'operator' => $this->legalOperatorRepository->find(),
            'recipients' => $this->forwardingRecipientRepository->findAll(),
        ]);
    }
}
```

This service returns only one page fragment and leaves shared component retrieval and complete page composition in the controller:

```php
$content = $this->privacyPolicyViewService->fetchContent();
$header = $this->siteHeaderViewModelFactory->createForLegalPage($locale, 'privacy-policy');
$legalNavigation = $this->legalNavigationViewModelFactory->create($locale, 'privacy-policy');

$page = new PrivacyPolicyPageViewModel(
    new PageMetadataViewModel($locale, 'Privacy policy'),
    $header,
    $content,
    $legalNavigation,
);
```

This interface is misplaced and uses a vague name. Its returned model is owned by a presentation module even though it represents a shared domain concept.

```php
namespace Example\App\Frontend\PrivacyPolicy;

interface PrivacyPolicyRecipientProvider
{
    /** @return list<PrivacyPolicyRecipient> */
    public function activeRecipients(): array;
}
```

This contract leaks storage details, repeats its subject, and represents absence as `null`:

```php
namespace Example\Domain\PrivacyPolicy;

interface PrivacyPolicyVersionRepository
{
    public function loadPrivacyPolicyVersionFromFile(): ?PrivacyPolicyVersion;
}
```
