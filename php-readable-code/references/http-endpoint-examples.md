# HTTP Endpoint Contracts And Examples

Select the convention by the endpoint contract. A POST method, JSON encoding, JavaScript submission, or server-rendered initial form alone does not identify a REST resource operation. The examples assume existing services, DTOs, validated controller-argument wiring, renderers, and response infrastructure; adapt them to the project rather than installing these collaborators solely to copy a snippet.

| Contract | Naming | Successful response |
| --- | --- | --- |
| REST resource creation, `POST /api/users` | `UserController::postUsers()`, `UserService::create(CreateUserRequest): User` | `201`, member `Location`, public resource representation |
| REST resource read, `GET /api/users/{userId}` | `UserController::getUsers()`, `UserService::read(...)` | Resource representation under the endpoint's read contract |
| Server-rendered page, `GET /{locale}/registration` | `RegistrationController::getRegistration()`, `RegistrationViewService::fetchPage()`, `RegistrationPageRenderer::render()` | Complete HTML page |
| Explicit traditional HTML form action, `POST /{locale}/registration` | `RegistrationController::postRegistration()`, `RegistrationService::register()` | Ordinarily a `303` redirect to an HTML page |

CRUD names apply to supported REST resource service operations. Repositories retain `find()`/`findAll()`; presentation queries retain `fetchPage()`. A capability operation that does not create, read, update, or delete a resource keeps its actual operation name.

## Completed REST Resource Creation

The collection requires `201 Created`, `Location`, and a public response body for completed REST creation. This is the agreed coding convention; HTTP itself does not mandate a representation body. `UserService::create()` accepts the same validated `CreateUserRequest`, owns creation and persistence, and returns the created `User` with its assigned identifier and authoritative values. The controller maps those returned values to the public representation. It does not echo the submitted DTO or serialize the domain object wholesale.

This example assumes that `User` exposes string `id`, `name`, and `email` values and that the existing named member route `users.read` uses the `userId` argument. Adapt property access and identifier conversion to the actual model. Use the existing route parser so a configured base path is included; do not concatenate a guessed URL or invent a URL-generator wrapper.

```php
<?php

declare(strict_types=1);

namespace Example\App\Frontend\User;

use Example\App\Frontend\Http\JsonResponseFactory;
use Psr\Http\Message\ResponseInterface;
use Slim\Interfaces\RouteParserInterface;

final readonly class UserResponse
{
    public function __construct(
        public string $id,
        public string $name,
        public string $email,
    ) {
    }
}

final class UserController
{
    public function __construct(
        private UserService $userService,
        private JsonResponseFactory $jsonResponseFactory,
        private RouteParserInterface $routeParserInterface,
    ) {
    }

    public function postUsers(CreateUserRequest $createUserRequest): ResponseInterface
    {
        $user = $this->userService->create($createUserRequest);
        $userResponse = new UserResponse($user->id, $user->name, $user->email);
        $location = $this->routeParserInterface->urlFor(
            'users.read',
            ['userId' => $user->id],
        );
        $response = $this->jsonResponseFactory->create($userResponse, 201);

        return $response->withHeader('Location', $location);
    }
}
```

The explicit response DTO excludes password, password hash, verification/recovery tokens, and session secrets even when the returned domain object holds them. Extend it with public server-assigned fields when the resource contract requires them. Keep the service free of PSR-7 requests/responses, route parsing, status selection, headers, and JSON serialization. Reuse an existing response mapper when mapping needs one; the simple constructor above does not require a new factory.

A typical wire response is:

```http
HTTP/1.1 201 Created
Location: /api/users/7d31c979-f3f0-4ef3-9d78-f9e4c0519248
Content-Type: application/json

{"id":"7d31c979-f3f0-4ef3-9d78-f9e4c0519248","name":"Alex","email":"alex@example.com"}
```

An already-created User may still await email verification; that lifecycle state does not make its creation asynchronous. A deliberately asynchronous endpoint may return `202` while processing remains incomplete. An action POST that creates no resource follows its own documented response contract. Surface an explicitly required compatibility conflict rather than silently treating an older generic success/pending response as the conventional completed-creation response.

## Server-rendered Page And Traditional HTML Form Action

Use this submission example only when the project or task explicitly requires an ordinary HTML form POST. Keep the normal JavaScript-managed default in `php-request-validation` otherwise. The GET rendering pattern applies to server-rendered pages regardless of how their forms submit.

The existing form middleware hydrates/validates once and supplies class-keyed `RegistrationValues` and `RegistrationValidationResult` on either outcome. Slim's configured invocation boundary delivers those typed parameters and raises `LogicException` for missing or wrongly typed required attributes. Preserve existing CSRF/authentication and localization wiring; these snippets focus on the controller contract.

`RegistrationViewService` returns one complete typed `RegistrationPageViewModel`. Its invalid-form operation maps only safe values for redisplay, excluding passwords and other secrets. The renderer receives that page as its sole application-data input, alongside the HTTP response and locale. The form service accepts the same validated values on the successful branch; there is no extra input DTO solely to change vocabulary.

```php
<?php

declare(strict_types=1);

namespace Example\App\Frontend\Registration;

use Example\App\Frontend\Localization\Locale;
use Psr\Http\Message\ResponseInterface;
use Slim\Interfaces\RouteParserInterface;

final class RegistrationController
{
    public function __construct(
        private RegistrationViewService $registrationViewService,
        private RegistrationPageRenderer $registrationPageRenderer,
        private RegistrationService $registrationService,
        private RouteParserInterface $routeParserInterface,
    ) {
    }

    public function getRegistration(
        ResponseInterface $response,
        string $locale,
    ): ResponseInterface {
        $selectedLocale = Locale::from($locale);
        $registrationPageViewModel = $this->registrationViewService->fetchPage($selectedLocale);

        return $this->registrationPageRenderer->render(
            $response,
            $selectedLocale,
            $registrationPageViewModel,
        );
    }

    public function postRegistration(
        RegistrationValues $registrationValues,
        RegistrationValidationResult $registrationValidationResult,
        ResponseInterface $response,
        string $locale,
    ): ResponseInterface {
        $selectedLocale = Locale::from($locale);
        if ($registrationValidationResult->hasErrors()) {
            $registrationPageViewModel = $this->registrationViewService->fetchPageWithValidationErrors(
                $selectedLocale,
                $registrationValues,
                $registrationValidationResult,
            );
            $unprocessableResponse = $response->withStatus(422);

            return $this->registrationPageRenderer->render(
                $unprocessableResponse,
                $selectedLocale,
                $registrationPageViewModel,
            );
        }

        $this->registrationService->register($registrationValues);
        $location = $this->routeParserInterface->urlFor(
            'registration.complete',
            ['locale' => $selectedLocale->value],
        );

        return $response->withStatus(303)->withHeader('Location', $location);
    }
}
```

This form action returns rendered HTML errors or an HTML navigation redirect. It does not need REST CRUD service names, a created-resource response DTO, or a `201` response. The presence of a `Location` header on the success redirect does not turn it into a REST creation response.

## Server-rendered Form Calling A REST Resource Endpoint

If PHP renders a registration page but its JavaScript submits to `POST /api/users`, keep both contracts visible. The page uses `RegistrationViewService::fetchPage()` and its renderer. Its submission endpoint uses `UserController`, `CreateUserRequest`, `UserService::create()`, and the `201`/`Location`/resource-body response above. A UI module may still call its user-facing capability `register()`; it does not determine the API service name.

The browser validates locally, retains inputs on failure, and owns displayed messages and localization. REST parsing/validation failures use the established Problem Details response without invoking the resource service. Do not add HTML submission handling to that API just because its initial form was server-rendered.

## Verification

For completed REST creation, verify that the same validated DTO reaches `create()`, the returned resource supplies the response identifier and values, `Location` targets that member with the configured base path, the status is `201`, and the JSON excludes secrets. Do not use `void` creation plus a fixed pending marker as the positive example.

For the HTML GET, use the real renderer to verify the complete page. For an explicitly required traditional form POST, verify invalid input renders safe preserved values with `422` and no service call, while valid input invokes the capability service and returns the success redirect. For a REST-backed form on an HTML page, verify each side against its own contract.
