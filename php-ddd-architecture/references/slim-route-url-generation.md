# Slim Route URL Generation

Use Slim's `RouteParserInterface` directly at the web boundary. Constructor injection exposes URL generation as a required controller dependency and avoids coupling otherwise-unused requests to route lookup.

## Controller

Do not retrieve the parser from `RouteContext`:

```php
final class ImprintController
{
    public function getImprint(
        ServerRequestInterface $request,
        ResponseInterface $response,
        string $locale,
    ): ResponseInterface {
        $routeParser = RouteContext::fromRequest($request)->getRouteParser();
        $imprintUrl = $routeParser->urlFor('imprint', ['locale' => $locale]);

        // ...
    }
}
```

Inject Slim's interface and remove the request when the action has no other use for it:

```php
use Slim\Interfaces\RouteParserInterface;

final class ImprintController
{
    public function __construct(
        private PhpRenderer $templates,
        private RouteParserInterface $routeParser,
    ) {
    }

    public function getImprint(
        ResponseInterface $response,
        string $locale,
    ): ResponseInterface {
        $imprintUrl = $this->routeParser->urlFor(
            'imprint',
            ['locale' => $locale],
        );

        // ...
    }
}
```

Keep `ServerRequestInterface` when the controller reads real request data:

```php
public function getDefaultLocale(
    ServerRequestInterface $request,
    ResponseInterface $response,
): ResponseInterface {
    $acceptLanguage = $request->getHeaderLine('Accept-Language');
    $locale = $this->localeSelector->select($acceptLanguage);
    $location = $this->routeParser->urlFor('home', ['locale' => $locale->value]);

    return $response->withHeader('Location', $location);
}
```

## PHP-DI Composition

Register the application route collector's parser after defining named routes. Use the mutable PHP-DI container already required by the PHP-DI Slim bridge rather than adding a URL-generator wrapper.

```php
use DI\Container;
use Slim\Interfaces\RouteParserInterface;

$application = Bridge::create($container);

$application->get('/{locale}/', [HomeController::class, 'getHome'])
    ->setName('home');
$application->get('/{locale}/imprint', [ImprintController::class, 'getImprint'])
    ->setName('imprint');

$container->set(
    RouteParserInterface::class,
    $application->getRouteCollector()->getRouteParser(),
);
```

## Unit Test

Mock `RouteParserInterface` at the controller boundary. A PSR-7 response may still be constructed because it is the action output; no request or `RouteContext` is needed solely for URL generation.

```php
$routeParser = $this->createMock(RouteParserInterface::class);
$routeParser->expects(self::once())
    ->method('urlFor')
    ->with('home', ['locale' => 'en'])
    ->willReturn('/en/');

$controller = new LocaleRedirectController(
    new AcceptLanguageLocaleSelector(),
    $routeParser,
);
$response = (new ResponseFactory())->createResponse();

$actual = $controller->getLocaleWithoutTrailingSlash($response, 'en');

self::assertSame('/en/', $actual->getHeaderLine('Location'));
```

HTTP integration tests may continue creating requests when they verify Slim dispatch, route registration, middleware, base paths, or other application-boundary behavior.
