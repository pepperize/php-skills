# Worked User Endpoint

This reference adapts the Zeitenlogger User endpoint organization into a small `POST /api/users` example. It creates a directory User with `name` and `email`; it is not a complete account-registration implementation. Credentials, verification, legal acceptance and notification rules must come from the target project.

Read the sections needed for the work:

- [Flow and naming](#flow-and-naming)
- [Layout](#layout)
- [Input and validation](#input-and-validation)
- [Entity and repository](#entity-and-repository)
- [Application service and public DTO](#application-service-and-public-dto)
- [Controller and HTTP response](#controller-and-http-response)
- [Composition](#composition)
- [Verification](#verification)

## Flow And Naming

The default resource flow is `Controller -> Service -> Repository`, optionally followed by a technical `Client` behind the repository. Identify each collaborator's role before naming it. The input DTO and output DTO are the service's contracts; the entity is the repository's contract. Factories bridge those representations.

| Collaborator | Responsibility and contract |
| --- | --- |
| `UserController` | Receives validated `CreateUserRequest`, calls `UserService` and delegates HTTP response creation. |
| `UserService` | Accepts `CreateUserRequest`, coordinates factories and the repository, and returns `UserDto`. |
| `UserFactory` | Constructs `User` from `CreateUserRequest` through `create(...)`. A product-specific name such as `PendingUserFactory` may distinguish an actual creation variant. |
| `UserRepository` | Accepts `User` for persistence and returns `User` with authoritative persisted values. Reads may accept identifiers or criteria. |
| `UserDtoFactory` | Constructs the output-only `UserDto` from the repository's returned `User` through `create(...)`. |
| `DoctrineUserRepository` | Implements the entity-facing repository contract using Doctrine; ORM access stays in this implementation. |

The creation operation makes the roles visible:

```text
UserController::postUsers(CreateUserRequest)
  -> UserService::create(CreateUserRequest): UserDto
       -> UserFactory::create(CreateUserRequest): User
       -> UserRepository::saveAndFlush(User): User
       -> UserDtoFactory::create(User): UserDto
  -> UserResponseFactory::create(UserDto): ResponseInterface
```

The service orchestrates the sequence. Its factories own DTO/entity construction; the controller does not receive an entity to translate, and the repository does not accept a request DTO or return a public response DTO. Use `<Product>Factory::create(...)` for these conversions. Mapping fields does not establish a separate `Mapper`, `Converter` or `Generator` role. Returning an object alone does not make the service or repository a factory: their primary responsibilities are application orchestration and persistence/retrieval.

`DoctrineUserRepository::saveAndFlush(User $user): User` is an example of the repository boundary. Doctrine may hydrate entities directly on reads; this flow does not require a second persistence model or an additional factory around ordinary ORM hydration.

When the data source is a remote API, the infrastructure path can be `Service -> Repository -> Client`. The client owns technical communication; the repository returns the application's entity. A factory can construct that entity from the client's transport DTO, while the service still uses its output DTO factory. See the [repository/client example](../../php-ddd-architecture/references/repositories.md#infrastructure-implementations) for this split. Keep factories that consume application DTOs in application code and factories that consume infrastructure transport types in infrastructure; domain repository contracts remain independent of both.

These suffixes name collaborators in the standard flow. Entities, DTOs and other data carriers have their own names. Other collaborator suffixes need a concrete different responsibility, such as `ValidationMiddleware`, `Validator`, `Renderer` or `Client`; explicit project conventions and server-rendered ViewService/Renderer flows remain in place. Add only the operations and collaborators the actual contract needs.

## Layout

For a DDD project with API controllers in its application layer:

```text
src/
├── App/Api/User/
│   ├── CreateUserRequest.php
│   ├── CreateUserRequestError.php
│   ├── CreateUserRequestHydrationResult.php
│   ├── CreateUserRequestHydrationResultFactory.php
│   ├── CreateUserRequestValidator.php
│   ├── UserController.php
│   ├── UserService.php
│   ├── UserDto.php
│   ├── UserDtoFactory.php
│   ├── UserFactory.php
│   ├── UserResponseFactory.php
│   ├── UserAlreadyExistsException.php
│   └── UserConflictException.php
├── Domain/
│   ├── Account/User.php
│   ├── Account/UserRepository.php
│   └── Shared/EntityExistsException.php
└── Infrastructure/
    ├── Account/Persistence/DoctrineUserRepository.php
    └── Http/User/CreateUserRequestValidationMiddleware.php
```

Each declared class belongs in its own file. `Example` is a replacement namespace. Reuse the project's existing JSON response factory and Problem Details handler. The examples assume PHP 8.2+, Symfony Validator, Slim 4, PSR-7/15 and, for the persistence section, Doctrine ORM with the Ramsey UUID generator already selected by the project. Do not install this stack into another framework merely to copy the example.

## Input And Validation

This example uses the following collaborator split to collect raw-input errors across fields and share typed errors with constraint validation:

- `CreateUserRequestHydrationResultFactory` checks raw shape and types, performs permitted normalization once, and constructs the input DTO.
- `CreateUserRequestValidator` invokes Symfony Validator and maps violations to typed `CreateUserRequestError` values.
- `CreateUserRequestValidationMiddleware` coordinates those collaborators, short-circuits errors through `UserResponseFactory`, and attaches the accepted DTO for dispatch.
- `UserResponseFactory` maps typed errors to the HTTP Problem Details envelope and encoded pointers.

Here the middleware coordinates the existing collaborators without inlining their implementations. These classes are one composition, not a required minimum for every endpoint. For simple hydration owned by one middleware, use a cohesive private construction method as shown in [local DTO construction](../../php-request-validation/references/local-dto-construction.md). Preserve the target contract, including raw-type checks, normalization, extra fields and error accumulation, whichever composition is chosen. The immutable input DTO is also the service parameter; `UserDto` is a separate output type.

This two-field illustration preserves the baseline's behavior for those fields: trim the name, trim and lowercase the email, ignore additional fields, and distinguish missing, null and wrong-type values. These are contract choices, not universal normalization or unknown-field policies; preserve the target project's actual contract. Password, locale and legal-document fields are omitted from this generic directory example.

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use Symfony\Component\Validator\Constraints\Email;
use Symfony\Component\Validator\Constraints\Length;
use Symfony\Component\Validator\Constraints\NotBlank;
use Symfony\Component\Validator\Constraints\Sequentially;

final readonly class CreateUserRequest
{
    public function __construct(
        #[Sequentially([
            new NotBlank(payload: 'REQUIRED_FIELD'),
            new Length(max: 100, payload: 'TOO_LONG'),
        ])]
        public string $name,
        #[Sequentially([
            new NotBlank(payload: 'REQUIRED_FIELD'),
            new Length(max: 254, payload: 'TOO_LONG'),
            new Email(
                mode: Email::VALIDATION_MODE_HTML5_ALLOW_NO_TLD,
                payload: 'INVALID_EMAIL',
            ),
        ])]
        public string $email,
    ) {
    }
}
```

Typed error values retain source path segments, application codes and safe diagnostics. Hydration and constraint failures use the same type; only the response collaborator encodes HTTP pointers.

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

final readonly class CreateUserRequestError
{
    /** @param list<string> $path */
    public function __construct(public array $path, public string $code, public string $message)
    {
    }
}
```

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

final readonly class CreateUserRequestHydrationResult
{
    /** @param list<CreateUserRequestError> $errors */
    public function __construct(public ?CreateUserRequest $request, public array $errors = [])
    {
    }
}
```

The hydration factory is adapted from the baseline with only the two supported fields. Raw checks run before constructing the strictly typed DTO; services and domain objects do not repeat these checks or normalization.

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

final class CreateUserRequestHydrationResultFactory
{
    /** @param array<array-key, mixed> $requestBody */
    public function create(array $requestBody): CreateUserRequestHydrationResult
    {
        $errors = $this->collectShapeErrors($requestBody);
        if ($errors !== []) {
            return new CreateUserRequestHydrationResult(null, $errors);
        }

        $name = trim($requestBody['name']);
        $email = mb_strtolower(trim($requestBody['email']));
        $createUserRequest = new CreateUserRequest(
            $name,
            $email,
        );

        return new CreateUserRequestHydrationResult($createUserRequest);
    }

    /**
     * @param array<array-key, mixed> $requestBody
     * @return list<CreateUserRequestError>
     */
    private function collectShapeErrors(array $requestBody): array
    {
        $types = [
            'name' => 'string',
            'email' => 'string',
        ];
        $errors = [];
        foreach ($types as $field => $type) {
            if (!array_key_exists($field, $requestBody)) {
                $errors[] = new CreateUserRequestError([$field], 'REQUIRED_FIELD', 'This field is required.');
                continue;
            }

            if ($requestBody[$field] === null) {
                $errors[] = new CreateUserRequestError([$field], 'NULL_NOT_ALLOWED', 'This field cannot be null.');
                continue;
            }

            if (gettype($requestBody[$field]) !== $type) {
                $message = 'Send a text value.';
                $errors[] = new CreateUserRequestError([$field], 'INVALID_TYPE', $message);
            }
        }

        return $errors;
    }
}
```

The validator runs the shared attribute-enabled Symfony validator and converts its result into the endpoint's typed error contract. This flat DTO's property names are identical to submitted field names; nested or renamed fields require the established path mapper.

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use Symfony\Component\Validator\Validator\ValidatorInterface;

final class CreateUserRequestValidator
{
    public function __construct(private ValidatorInterface $validator)
    {
    }

    /** @return list<CreateUserRequestError> */
    public function validate(CreateUserRequest $createUserRequest): array
    {
        $violations = $this->validator->validate($createUserRequest);
        $errors = [];

        foreach ($violations as $violation) {
            // Each flat DTO property has the same name as its submitted field.
            $path = [$violation->getPropertyPath()];
            $code = $violation->getConstraint()->payload;
            $message = (string) $violation->getMessage();
            $errors[] = new CreateUserRequestError(
                $path,
                $code,
                $message,
            );
        }

        return $errors;
    }
}
```

The existing parser/protection boundary must reject malformed JSON with HTTP 400 and non-object JSON with HTTP 422 before this middleware runs, while preserving valid JSON objects as `stdClass`. Its media-type, size and security policies stay in the established protection middleware. Consequently, a non-object parsed body here indicates broken route wiring and raises `LogicException`; it is not another client-validation branch.

```php
<?php

declare(strict_types=1);

namespace Example\Infrastructure\Http\User;

use LogicException;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;
use Example\App\Api\User\CreateUserRequest;
use Example\App\Api\User\CreateUserRequestHydrationResultFactory;
use Example\App\Api\User\CreateUserRequestValidator;
use Example\App\Api\User\UserResponseFactory;
use stdClass;

final class CreateUserRequestValidationMiddleware implements MiddlewareInterface
{
    public function __construct(
        private CreateUserRequestHydrationResultFactory $createUserRequestHydrationResultFactory,
        private CreateUserRequestValidator $createUserRequestValidator,
        private UserResponseFactory $userResponseFactory,
    ) {
    }

    public function process(
        ServerRequestInterface $request,
        RequestHandlerInterface $handler,
    ): ResponseInterface {
        $parsedBody = $request->getParsedBody();
        if (!$parsedBody instanceof stdClass) {
            throw new LogicException('User creation requires the JSON object parser.');
        }
        $requestBody = (array) $parsedBody;
        $hydrationResult = $this->createUserRequestHydrationResultFactory->create($requestBody);
        if ($hydrationResult->request === null) {
            return $this->userResponseFactory->createValidationProblem($hydrationResult->errors);
        }
        $createUserRequest = $hydrationResult->request;
        $errors = $this->createUserRequestValidator->validate($createUserRequest);
        if ($errors !== []) {
            return $this->userResponseFactory->createValidationProblem($errors);
        }
        $validatedRequest = $request->withAttribute(CreateUserRequest::class, $createUserRequest);

        return $handler->handle($validatedRequest);
    }
}
```

Preserve the target endpoint's locale selection and protection policies when they apply. Use the [Problem Details location rules](../../php-request-validation/references/problem-details.md) for nested, renamed and arbitrary paths. For regex fields, follow the one-full-value-regex rule in `php-request-validation`. Browser feedback uses frontend-owned messages selected from stable codes, never these API diagnostics.

## Entity And Repository

Mapping attributes describe the same domain object that the repository persists. There is no `UserRecord`, record factory or second set of persistence properties. The example's readonly entity represents creation; choose mutability for actual update and lifecycle requirements rather than making readonly a universal rule.

```php
<?php

declare(strict_types=1);

namespace Example\Domain\Account;

use DateTimeImmutable;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\Mapping\Column;
use Doctrine\ORM\Mapping\CustomIdGenerator;
use Doctrine\ORM\Mapping\Entity;
use Doctrine\ORM\Mapping\GeneratedValue;
use Doctrine\ORM\Mapping\Id;
use Doctrine\ORM\Mapping\Table;
use Doctrine\ORM\Mapping\UniqueConstraint;
use Ramsey\Uuid\Doctrine\UuidGenerator;

#[Entity]
#[Table(name: 'users')]
#[UniqueConstraint(name: 'uniq_users_email', columns: ['email'])]
final readonly class User
{
    #[Id]
    #[Column(type: Types::STRING, length: 36)]
    #[GeneratedValue(strategy: 'CUSTOM')]
    #[CustomIdGenerator(class: UuidGenerator::class)]
    public string $id;

    public function __construct(
        #[Column(type: Types::STRING, length: 100)]
        public string $name,
        #[Column(type: Types::STRING, length: 254)]
        public string $email,
        #[Column(name: 'created_at', type: Types::DATETIME_IMMUTABLE)]
        public DateTimeImmutable $createdAt,
    ) {
    }
}
```

If an entity has embedded domain values, map those existing values with `#[Embedded]` / `#[Embeddable]`, as with Zeitenlogger's `LegalAcknowledgement`. Do not invent an embedded value solely to demonstrate the attribute. Mapping metadata is allowed on domain models; entity managers, DBAL connections and persistence operations remain in infrastructure. Schema changes still use the existing migration system.

```php
<?php

declare(strict_types=1);

namespace Example\Domain\Shared;

use RuntimeException;

final class EntityExistsException extends RuntimeException
{
}
```

```php
<?php

declare(strict_types=1);

namespace Example\Domain\Account;

use Example\Domain\Shared\EntityExistsException;

interface UserRepository
{
    /** @throws EntityExistsException */
    public function saveAndFlush(User $user): User;
}
```

The following conflict classification follows the MariaDB baseline: after Doctrine's failed implicit flush transaction has rolled back, a bound lookup establishes whether the email exists. A unique constraint failure on the generated ID alone remains technical. Preserve the actual database's collation/uniqueness semantics and transaction handling; do not query an aborted transaction or reuse a closed entity manager. An outer transaction or another driver may require the project's existing transaction or constraint-classification mechanism instead.

```php
<?php

declare(strict_types=1);

namespace Example\Infrastructure\Account\Persistence;

use Doctrine\DBAL\Exception\UniqueConstraintViolationException;
use Doctrine\ORM\EntityManagerInterface;
use Example\Domain\Account\User;
use Example\Domain\Account\UserRepository;
use Example\Domain\Shared\EntityExistsException;

final class DoctrineUserRepository implements UserRepository
{
    public function __construct(private EntityManagerInterface $entityManager)
    {
    }

    public function saveAndFlush(User $user): User
    {
        try {
            $this->entityManager->persist($user);
            $this->entityManager->flush();
        } catch (UniqueConstraintViolationException $exception) {
            $existingId = $this->entityManager->getConnection()->createQueryBuilder()
                ->select('id')
                ->from('users')
                ->where('email = :email')
                ->setParameter('email', $user->email)
                ->fetchOne();
            if ($existingId === false) {
                throw $exception;
            }

            throw new EntityExistsException('The entity already exists.', previous: $exception);
        }

        return $user;
    }
}
```

Only `saveAndFlush` is needed here. Add `find`, `findOneBy`, `save` or other supported operations when callers actually need their contracts. Do not generate a generic CRUD repository, preflight email uniqueness in the DTO validator, or replace the database constraint with a race-prone existence check.

## Application Service And Public DTO

Factories construct the entity and its explicit public representation. `UserDto` is output-only and is independent of `CreateUserRequest`. If the real entity includes credentials, tokens or private fields, keep them out of this factory and DTO.

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use DateTimeImmutable;
use Example\Domain\Account\User;

class UserFactory
{
    public function create(CreateUserRequest $createUserRequest): User
    {
        $createdAt = new DateTimeImmutable();

        return new User($createUserRequest->name, $createUserRequest->email, $createdAt);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

final readonly class UserDto
{
    public function __construct(
        public string $id,
        public string $name,
        public string $email,
        public string $createdAt,
    ) {
    }
}
```

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use Example\Domain\Account\User;

class UserDtoFactory
{
    public function create(User $user): UserDto
    {
        $createdAt = $user->createdAt->format(DATE_ATOM);

        return new UserDto($user->id, $user->name, $user->email, $createdAt);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use RuntimeException;

final class UserAlreadyExistsException extends RuntimeException
{
}
```

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use Example\Domain\Account\UserRepository;
use Example\Domain\Shared\EntityExistsException;

class UserService
{
    public function __construct(
        private UserRepository $userRepository,
        private UserFactory $userFactory,
        private UserDtoFactory $userDtoFactory,
    ) {
    }

    public function create(CreateUserRequest $createUserRequest): UserDto
    {
        $user = $this->userFactory->create($createUserRequest);
        try {
            $createdUser = $this->userRepository->saveAndFlush($user);
        } catch (EntityExistsException $entityExistsException) {
            throw new UserAlreadyExistsException(
                'A user with this email already exists.',
                previous: $entityExistsException,
            );
        }

        return $this->userDtoFactory->create($createdUser);
    }
}
```

The service returns a DTO derived from the repository's result, including the generated ID. It does not return an entity for the controller to map, revalidate input, or know HTTP status, route names and JSON. Additional business operations stay in the service or focused collaborators as required by the real use case.

## Controller And HTTP Response

The controller translates the application failure at the HTTP boundary and delegates successful output. This exception example uses Mezzio Problem Details, matching the baseline; adapt to the target project's existing error contract rather than introducing Mezzio solely for it.

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use Psr\Http\Message\ResponseInterface;

final class UserController
{
    public function __construct(
        private UserService $userService,
        private UserResponseFactory $userResponseFactory,
    ) {
    }

    public function postUsers(CreateUserRequest $createUserRequest): ResponseInterface
    {
        try {
            $userDto = $this->userService->create($createUserRequest);
        } catch (UserAlreadyExistsException $userAlreadyExistsException) {
            throw new UserConflictException($userAlreadyExistsException);
        }

        return $this->userResponseFactory->create($userDto);
    }
}
```

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use Mezzio\ProblemDetails\Exception\CommonProblemDetailsExceptionTrait;
use Mezzio\ProblemDetails\Exception\ProblemDetailsExceptionInterface;
use RuntimeException;

final class UserConflictException extends RuntimeException implements ProblemDetailsExceptionInterface
{
    use CommonProblemDetailsExceptionTrait;

    public function __construct(UserAlreadyExistsException $userAlreadyExistsException)
    {
        $this->status = 409;
        $this->type = '/problems/user-already-exists';
        $this->title = 'User already exists';
        $this->detail = 'A user already uses this email address.';
        $this->additional = ['errors' => [
            ['pointer' => '#/email', 'code' => 'USER_ALREADY_EXISTS'],
        ]];

        parent::__construct($this->detail, $this->status, $userAlreadyExistsException);
    }
}
```

This disclosure is an illustrative directory-API contract. A real account endpoint must follow its established anti-enumeration requirements; do not change them incidentally while adopting the structure. Technical exceptions are handled by the existing server-error boundary without exposing internal diagnostics or adding duplicate logging here.

The response factory reuses the established `JsonResponseFactory::create(object|array $body, int $status, string $contentType)` and an existing named member route `users.read` with argument `userId`. The route parser includes the configured base path. Do not construct a guessed URL or serialize the domain entity.

```php
<?php

declare(strict_types=1);

namespace Example\App\Api\User;

use Example\App\Api\Http\JsonResponseFactory;
use Psr\Http\Message\ResponseInterface;
use Slim\Interfaces\RouteParserInterface;

class UserResponseFactory
{
    public function __construct(
        private JsonResponseFactory $jsonResponseFactory,
        private RouteParserInterface $routeParser,
    ) {
    }

    public function create(UserDto $userDto): ResponseInterface
    {
        $location = $this->routeParser->urlFor('users.read', ['userId' => $userDto->id]);
        $response = $this->jsonResponseFactory->create($userDto, 201, 'application/json');

        return $response->withHeader('Location', $location);
    }

    /** @param list<CreateUserRequestError> $errors */
    public function createValidationProblem(array $errors): ResponseInterface
    {
        $errorDetails = $this->createErrorDetails($errors);
        $body = [
            'type' => '/problems/validation-error',
            'title' => 'Validation failed',
            'status' => 422,
            'detail' => 'The request violates the API contract.',
            'errors' => $errorDetails,
        ];

        return $this->jsonResponseFactory->create($body, 422, 'application/problem+json');
    }

    /**
     * @param list<CreateUserRequestError> $errors
     * @return list<array{pointer: string, detail: string, code: string}>
     */
    private function createErrorDetails(array $errors): array
    {
        $details = [];
        foreach ($errors as $error) {
            $pointer = $this->createPointer($error->path);
            $details[] = [
                'pointer' => $pointer,
                'detail' => $error->message,
                'code' => $error->code,
            ];
        }

        return $details;
    }

    /** @param list<string> $path */
    private function createPointer(array $path): string
    {
        if ($path === []) {
            return '#';
        }

        $tokens = [];
        foreach ($path as $token) {
            $escapedToken = str_replace(['~', '/'], ['~0', '~1'], $token);
            $tokens[] = rawurlencode($escapedToken);
        }

        return '#/' . implode('/', $tokens);
    }
}
```

In a project with a shared validation responder, reuse it instead of copying `createValidationProblem`. No submitted values or exception messages are included in these diagnostics. Completed resource creation requires `201`, `Location` and the public DTO body by this collection's convention; HTTP itself does not mandate the body. An entity awaiting a later lifecycle transition is still a created resource.

## Composition

Keep composition in infrastructure. Reuse the existing entity-manager factory with attribute mapping enabled for the domain entity directories and any embedded values. Bind the domain repository interface to `DoctrineUserRepository`; do not inject the entity manager into the application service. Keep database migrations in the project's existing migration system.

For a PHP-DI/Slim composition, these are the resource-specific additions to the existing definitions:

```php
use Example\Domain\Account\UserRepository;
use Example\Infrastructure\Account\Persistence\DoctrineUserRepository;
use Symfony\Component\Validator\Validation;
use Symfony\Component\Validator\Validator\ValidatorInterface;

$definitions[UserRepository::class] = DI\autowire(DoctrineUserRepository::class);
$definitions[ValidatorInterface::class] = static function (): ValidatorInterface {
    return Validation::createValidatorBuilder()->enableAttributeMapping()->getValidator();
};
```

If those shared bindings already exist, keep them. `EntityManagerInterface` and `JsonResponseFactory` come from the existing infrastructure. Register `RouteParserInterface` from the application's route collector once after creating the app. Do not put request DTO instances in the container.

Use the project's established typed invocation strategy. For PHP-DI Slim Bridge, read and adapt [Slim controller arguments](../../php-request-validation/references/slim-controller-arguments.md): register `CreateUserRequest::class` explicitly with the guarded resolver before name-based and container fallback. The action's typed parameter alone does not enable class-keyed binding. Missing or wrongly typed required attributes raise `LogicException` before controller invocation.

```php
use Example\App\Api\User\UserController;
use Example\Infrastructure\Http\User\CreateUserRequestValidationMiddleware;

// $jsonObjectParsingMiddleware is the existing parser/protection boundary.
// It rejects malformed/non-object JSON and supplies a stdClass parsed body.
// $controllerInvoker is the existing configured, guarded invocation strategy.
$app->post('/api/users', [UserController::class, 'postUsers'])
    ->setName('users.create')
    ->setInvocationStrategy($controllerInvoker)
    ->add(CreateUserRequestValidationMiddleware::class)
    ->add($jsonObjectParsingMiddleware);
```

The canonical member route `users.read` is assumed to exist; its implementation is outside this creation example. Ensure `Location` uses the actual project's canonical member route. The surrounding pipeline must handle JSON parsing before validation, preserve existing size/media-type, authentication, authorization and CSRF protection, and wrap exceptions with the established Problem Details handler. Slim executes middleware in reverse registration order; verify the actual pipeline rather than inferring order from the snippet.

## Verification

Use `php-testing-style` and the real components at the boundaries changed:

- The hydration factory distinguishes missing, null and wrong-type values, normalizes accepted fields exactly once and preserves the declared unknown-field policy. The real attribute-enabled validator returns typed errors for invalid values; the middleware short-circuits either failure without invoking the next handler.
- The parser/protection boundary rejects malformed JSON with 400 and non-object JSON with 422 before validation. Bypassing its stdClass guarantee raises a wiring `LogicException` in validation middleware. The response factory alone serializes typed errors and correctly escapes/encodes pointer segments.
- Real Slim dispatch delivers the class-keyed request DTO and the controller forwards the same instance. A missing/wrong-type attribute is a wiring `LogicException`, and successive requests do not reuse submitted DTOs.
- The service maps the entity returned by `saveAndFlush`, not the input request. The real repository loads attribute metadata, assigns an ID, flushes and round-trips stored values.
- The response is `201`, its member `Location` includes the configured base path and actual generated ID, and JSON contains only the public DTO fields. Where the real entity holds secrets, verify their exclusion.
- An established duplicate-email conflict follows the repository/application/HTTP exception chain, preserving causes. Unrelated integrity and technical failures remain server failures.

Reuse existing coverage for unchanged collaborators. These examples guide implementation; they do not require adding a new test framework, generic endpoint generator or every possible operation.
