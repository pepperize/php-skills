# HTTP Endpoint Contracts And Examples

Apply [Endpoint Contracts](../../php-api-endpoints/SKILL.md#endpoint-contracts), [REST API Naming](../SKILL.md#rest-api-naming), and [Traditional HTML Submissions](../../php-request-validation/SKILL.md#traditional-html-submissions). The examples below illustrate those owners using existing services, DTOs, validated argument wiring, renderers, and response infrastructure; adapt them rather than installing collaborators solely to copy a snippet.

| Contract | Naming | Successful response |
| --- | --- | --- |
| REST resource creation, `POST /api/users` | `UserController::postUsers()`, `UserService::create(CreateUserRequest): UserDto` | `201`, member `Location`, public resource representation |
| REST resource read, `GET /api/users/{userId}` | `UserController::getUsers()`, `UserService::read(...)` | Resource representation under the endpoint's read contract |
| Server-rendered page, `GET /{locale}/registration` | `RegistrationController::getRegistration()`, `RegistrationViewService::fetchPage()`, `RegistrationPageRenderer::render()` | Complete HTML page |
| Explicit traditional HTML form action, `POST /{locale}/registration` | `RegistrationController::postRegistration()`, `RegistrationService::register()` | Ordinarily a `303` redirect to an HTML page |

CRUD names apply to supported REST resource service operations. Repositories follow [Repository Method Naming](../SKILL.md#repository-method-naming); presentation queries retain `fetchPage()`. A capability operation that does not create, read, update, or delete a resource keeps its actual operation name.

## Completed REST Resource Creation

Read the [worked User endpoint](../../php-api-endpoints/references/user-endpoint.md) before implementing this contract. It owns the complete controller/service/DTO/repository example and validation/composition connections.

Under the [HTTP Response Contract](../../php-api-endpoints/SKILL.md#http-response-contract), this controller delegates the service's public `UserDto` to `UserResponseFactory`. The full User reference shows persistence, output mapping, named-route URL generation, and response serialization.

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
        $userDto = $this->userService->create($createUserRequest);

        return $this->userResponseFactory->create($userDto);
    }
}
```

This success-path excerpt omits the application-to-HTTP exception translation shown in the full reference. The DTO factory explicitly selects public fields and excludes passwords, hashes, tokens and session secrets. Never echo the submitted request or serialize the entity wholesale. The separate request and output DTOs can evolve independently; `UserDto` is not shared input.

A typical wire response is:

```http
HTTP/1.1 201 Created
Location: /api/users/7d31c979-f3f0-4ef3-9d78-f9e4c0519248
Content-Type: application/json

{"id":"7d31c979-f3f0-4ef3-9d78-f9e4c0519248","name":"Alex","email":"alex@example.com","createdAt":"2026-10-18T12:00:00+00:00"}
```

For pending verification, asynchronous processing, action POSTs, and compatibility exceptions, use the owning [HTTP Response Contract](../../php-api-endpoints/SKILL.md#http-response-contract).

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
        private RouteParserInterface $routeParser,
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
        $location = $this->routeParser->urlFor(
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

For completed REST creation, verify that the same validated DTO reaches `create()`, the persisted entity supplies the public service DTO's identifier and values, the controller delegates that DTO to the response collaborator, `Location` targets that member with the configured base path, the status is `201`, and the JSON excludes secrets. Do not use `void` creation plus a fixed pending marker as the positive example.

For the HTML GET, use the real renderer to verify the complete page. For an explicitly required traditional form POST, verify invalid input renders safe preserved values with `422` and no service call, while valid input invokes the capability service and returns the success redirect. For a REST-backed form on an HTML page, verify each side against its own contract.
