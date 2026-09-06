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

Application and frontend code consume only domain contracts:

```php
namespace Example\App\Frontend\PrivacyPolicy;

use Example\Domain\Inquiry\ForwardingRecipientRepository;
use Example\Domain\LegalOperator\LegalOperatorRepository;

final class PrivacyPolicyController
{
    public function __construct(
        private LegalOperatorRepository $legalOperatorRepository,
        private ForwardingRecipientRepository $recipientRepository,
    ) {
    }
}
```

## Incorrect Boundaries

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
