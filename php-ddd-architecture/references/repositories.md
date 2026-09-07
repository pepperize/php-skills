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

A repository that returns a list uses `findAll()` and returns an empty list when there are no results.

```php
namespace Example\Domain\Inquiry;

interface ForwardingRecipientRepository
{
    /** @return list<ForwardingRecipient> */
    public function findAll(): array;
}
```

If several workflows consume the recipients, keep the shared `ForwardingRecipient` model in the domain instead of creating a frontend-specific `PrivacyPolicyRecipient` copy.

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

When retrieval uses a remote API, keep the domain-facing retrieval contract on the repository and let its infrastructure implementation call a technical client:

```php
namespace Example\Infrastructure\LegalOperator;

use Example\Domain\LegalOperator\LegalOperator;
use Example\Domain\LegalOperator\LegalOperatorRepository;

final class RemoteLegalOperatorRepository implements LegalOperatorRepository
{
    public function __construct(private LegalOperatorClient $client)
    {
    }

    public function find(): LegalOperator
    {
        $response = $this->client->fetchLegalOperator();

        return new LegalOperator(
            $response->name,
            $response->postalAddressLines,
            $response->email,
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
        private ForwardingRecipientRepository $recipientRepository,
        private PublicEmailProtector $emailProtector,
        private SiteHeaderViewModelFactory $siteHeaderFactory,
        private LegalNavigationViewModelFactory $legalNavigationFactory,
    ) {
    }

    public function fetchPage(Locale $locale): PrivacyPolicyPageViewModel
    {
        $metadata = new PageMetadataViewModel($locale, 'Privacy policy');
        $header = $this->siteHeaderFactory->createForLegalPage(
            $locale,
            'privacy-policy',
        );
        $content = $this->fetchContent();
        $legalNavigation = $this->legalNavigationFactory->create(
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
        $protectedOperatorEmail = $this->emailProtector->protect($legalOperator->email);
        $operator = new PrivacyPolicyContactViewModel(
            $legalOperator->name,
            $protectedOperatorEmail,
        );
        $recipients = [];

        foreach ($this->recipientRepository->findAll() as $recipient) {
            $protectedRecipientEmail = $this->emailProtector->protect($recipient->email);
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
        private PhpRenderer $templates,
        private PrivacyPolicyViewService $privacyPolicyViewService,
    ) {
    }

    public function getPrivacyPolicy(
        ResponseInterface $response,
        string $locale,
    ): ResponseInterface {
        $selectedLocale = Locale::from($locale);
        $page = $this->privacyPolicyViewService->fetchPage($selectedLocale);
        $renderedResponse = $this->templates->render(
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
        private ForwardingRecipientRepository $recipientRepository,
    ) {
    }

    public function getPrivacyPolicy(
        ServerRequestInterface $request,
        ResponseInterface $response,
    ): ResponseInterface {
        return $this->templates->render($response, 'privacy-policy.php', [
            'operator' => $this->legalOperatorRepository->find(),
            'recipients' => $this->recipientRepository->findAll(),
        ]);
    }
}
```

This service returns only one page fragment and leaves shared component retrieval and complete page composition in the controller:

```php
$content = $this->privacyPolicyViewService->fetchContent();
$header = $this->siteHeaderFactory->createForLegalPage($locale, 'privacy-policy');
$legalNavigation = $this->legalNavigationFactory->create($locale, 'privacy-policy');

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
