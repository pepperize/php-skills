# Slim Controller Arguments

Use this reference when a Slim controller should receive a validated request DTO directly, for example `postUsers(CreateUserRequest $createUserRequest): ResponseInterface`. Hydration and field validation still run in route middleware; argument resolution only delivers the accepted object.

## Delivery Contract

- Validation middleware selects the route's DTO explicitly, rejects invalid input through the established responder, and attaches the accepted object with `withAttribute(CreateUserRequest::class, $createUserRequest)` before delegating.
- Register required DTO types explicitly in invocation configuration, or reuse the project's existing route metadata or request-DTO contract. Do not infer them from URL strings, class-name suffixes, namespaces, or every object parameter. Keep route validation and invocation declarations consistent.
- For registered DTO parameters, the class-keyed attribute takes precedence over parameter-name attributes, route placeholders, defaults, and DI service lookup. Renaming the parameter must not change binding. Require the object to have the declared type; an attribute with the same parameter name is not a substitute.
- Missing, null, or wrongly typed required DTO attributes are route-wiring failures. Throw `LogicException` at the invocation boundary before the controller runs. Do not turn them into client validation responses or catch unrelated `TypeError`/`Throwable` as HTTP 422.
- Keep request DTO instances in the current PSR-7 request. Never register them as container services, capture them in application-lifetime closures, or cache them in the resolver. Configuration may retain class names, not submitted values.
- After binding, follow [Request DTOs And Hydration](../SKILL.md#request-dtos-and-hydration) for the controller-to-service handoff. Keep `ServerRequestInterface` only for other request data; application services and domain objects do not receive it.
- Adapt affected routes and preserve existing authentication, authorization, CSRF, parsing, validation, and error-handling order. Do not migrate unrelated endpoints as part of adopting this convention.

## PHP-DI Slim Bridge

Inspect the installed versions and composition first. The [PHP-DI Slim bridge](https://php-di.org/doc/frameworks/slim.html#controller-parameters) injects request attributes by parameter name; its default type-based resolver looks up container services. A DTO type declaration alone therefore does not bind the existing class-keyed request attribute.

Reuse `DI\Bridge\Slim\ControllerInvoker` and Invoker's `TypeHintResolver` when available. The latter maps class-keyed supplied arguments but does not enforce the delivery contract when an entry is absent or has the wrong type. A focused resolver can guard explicitly registered DTO types and delegate the actual mapping to it. Run that resolver before `AssociativeArrayResolver` and `TypeHintContainerResolver` so neither can supply an alternative DTO.

The following example supports required, non-nullable, named class types. Adapt the namespace and configured types to the project; do not expand it into a body mapper, general attribute framework, or arbitrary union/collection argument system.

```php
<?php

declare(strict_types=1);

namespace Example\Infrastructure\Http;

use Invoker\ParameterResolver\ParameterResolver;
use Invoker\ParameterResolver\TypeHintResolver;
use LogicException;
use ReflectionFunctionAbstract;
use ReflectionNamedType;

final class RequestDtoParameterResolver implements ParameterResolver
{
    /** @param list<class-string> $requestDtoClasses */
    public function __construct(
        private TypeHintResolver $typeHintResolver,
        private array $requestDtoClasses,
    ) {
    }

    public function getParameters(
        ReflectionFunctionAbstract $reflection,
        array $providedParameters,
        array $resolvedParameters,
    ): array {
        $requestDtoParameters = [];
        foreach ($reflection->getParameters() as $index => $parameter) {
            if (array_key_exists($index, $resolvedParameters)) {
                continue;
            }
            $parameterType = $parameter->getType();
            if (!$parameterType instanceof ReflectionNamedType
                || !in_array($parameterType->getName(), $this->requestDtoClasses, true)) {
                continue;
            }
            $requestDtoClass = $parameterType->getName();
            $requestDto = $providedParameters[$requestDtoClass] ?? null;
            if (!$requestDto instanceof $requestDtoClass) {
                throw new LogicException(
                    'The route requires a validated request attribute of type ' . $requestDtoClass . '.',
                );
            }
            $requestDtoParameters[$requestDtoClass] = $requestDto;
        }

        return $this->typeHintResolver->getParameters(
            $reflection,
            $requestDtoParameters,
            $resolvedParameters,
        );
    }
}
```

Compose the strategy with the existing container and install it after `Bridge::create()` and before registering affected routes. Preserve any additional resolvers or invocation behavior that the project already requires.

```php
use DI\Bridge\Slim\Bridge;
use DI\Bridge\Slim\ControllerInvoker;
use Example\App\Frontend\User\CreateUserRequest;
use Example\App\Frontend\User\UserController;
use Example\Infrastructure\Http\RequestDtoParameterResolver;
use Example\Infrastructure\Http\User\CreateUserRequestValidationMiddleware;
use Invoker\Invoker;
use Invoker\ParameterResolver\AssociativeArrayResolver;
use Invoker\ParameterResolver\Container\TypeHintContainerResolver;
use Invoker\ParameterResolver\DefaultValueResolver;
use Invoker\ParameterResolver\ResolverChain;
use Invoker\ParameterResolver\TypeHintResolver;

// $container is the application's existing configured PHP-DI container.
$app = Bridge::create($container);
$requestDtoParameterResolver = new RequestDtoParameterResolver(
    new TypeHintResolver(),
    [CreateUserRequest::class],
);
$resolverChain = new ResolverChain([
    $requestDtoParameterResolver,
    new AssociativeArrayResolver(),
    new TypeHintContainerResolver($container),
    new DefaultValueResolver(),
]);
$invoker = new Invoker($resolverChain, $container);
$controllerInvoker = new ControllerInvoker($invoker);
$app->getRouteCollector()->setDefaultInvocationStrategy($controllerInvoker);

$app->post('/api/users', [UserController::class, 'postUsers'])
    ->add(CreateUserRequestValidationMiddleware::class);
```

The example assumes the DTO, controller, and validation middleware already exist and parsing precedes validation. Its resolver and composition were exercised through real Slim dispatch with PHP 8.4, Slim 4.15.3, PHP-DI 7.1.1, slim-bridge 3.4.1, and Invoker 2.3.7. For explicitly required ordinary HTML submissions, register both the values and validation-result types; middleware still supplies both outcomes and the controller decides whether to render errors or invoke the operation.

## Other Slim Compositions

Without the PHP-DI bridge, extend the project's existing invocation adapter or use Slim's [`InvocationStrategyInterface`](https://www.slimframework.com/docs/v4/objects/routing.html#route-strategies). Resolve explicitly declared DTO parameters from request attributes, apply the same guards, and preserve the existing callable, request/response, route-argument, and service handling. Keep framework-dependent resolution in infrastructure. Do not install PHP-DI, replace the container, or create another framework solely to obtain typed DTO parameters.

When only selected routes require a custom strategy, use Slim's route-level `setInvocationStrategy()` rather than changing unrelated dispatch behavior. When changing the default, set it before creating routes because each route receives its strategy at registration.

## Verification

Follow `php-testing-style`. Verify the changed invocation boundary through real Slim routing and dispatch, not just a direct call to the controller or resolver:

- Accepted input reaches the action as the same validated DTO object; renaming the parameter does not affect binding.
- A conflicting name-keyed value or route placeholder cannot override the class-keyed DTO. Missing, null, and wrong-type class-keyed attributes raise `LogicException` before controller or application operations run, even if a container entry or name-keyed object exists for that DTO.
- Invalid input returns the existing Problem Details response from middleware without reaching dispatch or business operations; use the real parser and validator metadata for affected pipeline tests.
- Successive requests through the same application receive distinct DTO objects with their own values. No submitted DTO is retained in the container or resolver.
- Existing request/response, route-placeholder, ordinary request-attribute, optional-default, and service injection still work at the changed boundary.

Check that every affected DTO parameter is explicitly declared in invocation configuration and covered by its route's validation middleware. Test application boot and route registration when composition changes. Keep exception assertions focused on the operation under test, and do not introduce logging or a client-error response for a programming/wiring failure merely to make the test pass.
