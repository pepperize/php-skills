# Local DTO Construction

Use a focused private method when raw-input checks and DTO construction belong to one middleware. The method completes an operation the caller needs; it does not just rename a field-presence expression. A separate factory or hydration-result wrapper needs a concrete benefit such as independent reuse, complex construction or required error accumulation.

For example, interleaving these details with validation makes the orchestration harder to read:

```php
if (!array_key_exists('token', $body)) {
    throw new InvalidRequestBodyException(['token'], 'This field is required.');
}
if (!is_string($body['token'])) {
    throw new InvalidRequestBodyException(['token'], 'Send a text value.');
}
if (array_diff(array_keys($body), ['token']) !== []) {
    throw new InvalidRequestBodyException([], 'Unknown fields are not allowed.');
}
$requestDto = new VerifyEmailRequest($body['token']);
$errors = $this->requestValidator->validate($requestDto);
```

Extract that complete operation so the middleware reveals construction, constraint validation and dispatch. This example assumes an existing immutable `VerifyEmailRequest` with attribute constraints, a shared `RequestValidator` returning typed `RequestError` values, and a `ProblemResponseFactory` owning HTTP serialization. Adapt their names and signatures to the project rather than adding parallel infrastructure.

The parser/protection middleware already guarantees an object body. This illustrative contract accepts only a required string `token`, rejects extra fields, does not normalize the value and permits reporting the first raw-input error. Invalid input returns the skill's default 422; preserve a target project's explicitly established status instead.

```php
<?php

declare(strict_types=1);

namespace Example\Infrastructure\Http\EmailVerification;

use Example\App\Api\EmailVerification\VerifyEmailRequest;
use Example\App\Http\ProblemResponseFactory;
use Example\App\Http\RequestError;
use Example\App\Http\RequestValidator;
use LogicException;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;
use stdClass;

final class VerifyEmailRequestValidationMiddleware implements MiddlewareInterface
{
    public function __construct(
        private RequestValidator $requestValidator,
        private ProblemResponseFactory $problemResponseFactory,
    ) {
    }

    public function process(ServerRequestInterface $request, RequestHandlerInterface $handler): ResponseInterface
    {
        $body = $request->getParsedBody();
        if (!$body instanceof stdClass) {
            throw new LogicException('Verification requires the JSON object parser.');
        }

        try {
            $requestDto = $this->createRequestDto((array) $body);
        } catch (InvalidRequestBodyException $exception) {
            $errors = [new RequestError($exception->path, $exception->getMessage())];

            return $this->problemResponseFactory->create($request, 422, $errors);
        }

        $errors = $this->requestValidator->validate($requestDto);
        if ($errors !== []) {
            return $this->problemResponseFactory->create($request, 422, $errors);
        }

        return $handler->handle($request->withAttribute(VerifyEmailRequest::class, $requestDto));
    }

    /** @param array<array-key, mixed> $body */
    private function createRequestDto(array $body): VerifyEmailRequest
    {
        if (!array_key_exists('token', $body)) {
            throw new InvalidRequestBodyException(['token'], 'This field is required.');
        }
        if (!is_string($body['token'])) {
            throw new InvalidRequestBodyException(['token'], 'Send a text value.');
        }
        if (array_diff(array_keys($body), ['token']) !== []) {
            throw new InvalidRequestBodyException([], 'Unknown fields are not allowed.');
        }

        return new VerifyEmailRequest($body['token']);
    }
}
```

Reuse an equivalent specific boundary exception when the project already has one. Otherwise this exception belongs beside the middleware in its own file, not in the application or domain model:

```php
<?php

declare(strict_types=1);

namespace Example\Infrastructure\Http\EmailVerification;

use RuntimeException;

final class InvalidRequestBodyException extends RuntimeException
{
    /** @param list<string> $path */
    public function __construct(public readonly array $path, string $message)
    {
        parent::__construct($message);
    }
}
```

The helper detects the raw-input failure; the middleware selects its HTTP response. Only fixed, safe diagnostics enter this exception. Raw types are checked before the strictly typed constructor, and `TypeError` remains a programming failure. Constraint validation and the next handler are outside the construction catch, so their failures cannot be mistaken for raw-input errors.

Do not copy first-failure behavior over an existing contract that collects multiple errors. In that case, retain an error-collecting result or existing hydration collaborator. The extraction boundary should clarify the operation while preserving its behavior.
