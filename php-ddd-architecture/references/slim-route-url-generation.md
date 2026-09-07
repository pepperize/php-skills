# Slim Route URL Generation

Use Slim's `RouteParserInterface` directly in the frontend presentation collaborator that owns the generated URLs. Constructor injection exposes URL generation as a required dependency and avoids coupling an otherwise-unused request to route lookup.

## Server-rendered Pages

Do not retrieve the parser from `RouteContext` inside a controller:

```php
final class PrivacyPolicyController
{
    public function getPrivacyPolicy(
        ServerRequestInterface $request,
        ResponseInterface $response,
        string $locale,
    ): ResponseInterface {
        $routeParser = RouteContext::fromRequest($request)->getRouteParser();
        $privacyPolicyUrl = $routeParser->urlFor(
            'privacy-policy',
            ['locale' => $locale],
        );

        // ...
    }
}
```

For a server-rendered page, put route-derived component data in the frontend ViewService or a shared ViewModel factory. The controller calls the ViewService and gives its complete page ViewModel to the renderer:

```php
use Slim\Interfaces\RouteParserInterface;

final class LegalNavigationViewModelFactory
{
    public function __construct(private RouteParserInterface $routeParser)
    {
    }

    public function create(Locale $locale, string $currentRouteName): LegalNavigationViewModel
    {
        $imprintUrl = $this->routeParser->urlFor(
            'imprint',
            ['locale' => $locale->value],
        );
        $privacyPolicyUrl = $this->routeParser->urlFor(
            'privacy-policy',
            ['locale' => $locale->value],
        );

        return new LegalNavigationViewModel([
            new LegalNavigationLinkViewModel(
                'Imprint',
                $imprintUrl,
                $currentRouteName === 'imprint',
            ),
            new LegalNavigationLinkViewModel(
                'Privacy policy',
                $privacyPolicyUrl,
                $currentRouteName === 'privacy-policy',
            ),
        ]);
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

Keep `ServerRequestInterface` when the controller reads real request data. A redirect-only controller may own route generation directly because it does not build a server-rendered page:

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

Mock `RouteParserInterface` at the frontend presentation collaborator that owns URL generation. Do not construct a request or `RouteContext` solely to provide URL generation.

```php
$routeParser = $this->createMock(RouteParserInterface::class);
$routeParser->expects(self::exactly(2))
    ->method('urlFor')
    ->willReturnMap([
        ['imprint', ['locale' => 'en'], '/en/imprint'],
        ['privacy-policy', ['locale' => 'en'], '/en/privacy-policy'],
    ]);

$factory = new LegalNavigationViewModelFactory($routeParser);

$actual = $factory->create(Locale::English, 'privacy-policy');

self::assertSame('/en/imprint', $actual->links[0]->url);
self::assertSame('/en/privacy-policy', $actual->links[1]->url);
```

HTTP integration tests may continue creating requests when they verify Slim dispatch, route registration, middleware, base paths, or other application-boundary behavior.
