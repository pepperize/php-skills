# Engineering Principles for PHP Design Reviews

Use these principles to explain observed design risks and choose proportionate improvements. They are heuristics, not a scorecard. A review should mention only principles that materially clarify a finding.

## DRY — Don’t Repeat Yourself

**Intent**

Keep each piece of knowledge, business rule, protocol, or mapping authoritative in one place so one change does not require synchronized edits.

**What to look for during review**

Look for repeated business decisions, validation rules, constants, mappings, or protocol details that must always change together. Distinguish duplicated knowledge from code that only looks similar.

**Typical violation**

Two entry points independently encode the same discount threshold and percentage.

**When the principle should not be applied mechanically**

Do not extract an abstraction from coincidentally similar code before its shared meaning is stable. A small amount of duplication can be cheaper than coupling two concepts that will evolve separately.

**Negative example**

```php
final class CheckoutController
{
    public function discount(int $loyaltyPoints): int
    {
        return $loyaltyPoints >= 1_000 ? 10 : 0;
    }
}

final class QuoteController
{
    public function discount(int $loyaltyPoints): int
    {
        return $loyaltyPoints >= 1_000 ? 10 : 0;
    }
}
```

The loyalty rule has two authorities. Changing the threshold or percentage can make quotes disagree with checkout.

**Positive example**

```php
final class LoyaltyDiscountPolicy
{
    public function percentageFor(int $loyaltyPoints): int
    {
        return $loyaltyPoints >= 1_000 ? 10 : 0;
    }
}
```

Both entry points can use the policy, giving the business rule one name and one place to change.

## KISS — Keep it simple, stupid

**Intent**

Use the least complex design that clearly satisfies current requirements.

**What to look for during review**

Look for indirection, configuration, generic machinery, patterns, branches, or layers whose cost exceeds the problem they solve.

**Typical violation**

A fixed formatting rule is implemented through a registry, strategy interface, factory, and configuration map.

**When the principle should not be applied mechanically**

Simple does not mean compressed, clever, or globally minimal. A named collaborator or explicit branch can be worthwhile when it makes important behavior easier to understand or test.

**Negative example**

```php
interface SlugStrategy
{
    public function create(string $title): string;
}

final class SlugStrategyRegistry
{
    /** @param array<string, SlugStrategy> $strategies */
    public function __construct(private array $strategies) {}

    public function for(string $name): SlugStrategy
    {
        return $this->strategies[$name];
    }
}
```

If the application has one fixed slug rule, the extension machinery makes a simple operation harder to trace.

**Positive example**

```php
final class Slugger
{
    public function slug(string $title): string
    {
        return strtolower(str_replace(' ', '-', trim($title)));
    }
}
```

The current behavior is direct and has a clear home. More structure can be introduced when real variation appears.

## FCoI — Favour Composition over Inheritance

**Intent**

Assemble behavior from focused collaborators when inheritance would couple a subtype to implementation details or use an “is-a” relationship only for reuse.

**What to look for during review**

Look for subclasses that inherit irrelevant API, override hooks in fragile sequences, access protected state, or cannot safely stand in for the parent. Check whether delegation expresses the relationship more accurately.

**Typical violation**

A report exporter extends a PDF document solely to reuse PDF rendering methods.

**When the principle should not be applied mechanically**

Do not reject inheritance that models a genuine substitutable hierarchy, is required by a framework contract, and preserves LSP. Composition also has a cost when it only adds forwarding layers.

**Negative example**

```php
final class SalesReportExporter extends PdfDocument
{
    public function export(SalesReport $report): string
    {
        $this->addPage();
        $this->write($report->summary());

        return $this->bytes();
    }
}
```

A sales report is not a PDF document. The exporter inherits the document’s whole API and lifecycle just to reuse behavior.

**Positive example**

```php
final class SalesReportExporter
{
    public function __construct(private PdfRenderer $pdfRenderer) {}

    public function export(SalesReport $report): string
    {
        return $this->pdfRenderer->render($report->summary());
    }
}
```

Composition exposes the actual relationship and lets the renderer evolve independently of report export.

## IOSP — Integration Operation Segregation Principle

**Intent**

Separate methods that coordinate collaborators and side effects from methods that contain decisions or transformations. Integration code should reveal the flow; operational logic should be independently understandable and testable.

**What to look for during review**

Look for methods that interleave database or network calls with loops, calculations, policy decisions, and mutation. Check whether extracting a meaningful operation would leave a short orchestration method.

**Typical violation**

A reminder job fetches records, calculates which are overdue, formats messages, and sends network requests inside one loop.

**When the principle should not be applied mechanically**

Do not extract one-line wrappers or treat ordinary language primitives and value-object access as forbidden calls. Small cohesive methods may mix trivial coordination and logic when separation would obscure rather than clarify the behavior.

**Negative example**

```php
public function sendReminders(DateTimeImmutable $today): void
{
    foreach ($this->orderRepository->findBy(['status' => 'open']) as $order) {
        if ($order->dueDate() < $today && !$order->isDisputed()) {
            $this->mailer->send($order->customerEmail(), 'Payment overdue');
        }
    }
}
```

I/O orchestration and the overdue-selection rule are interleaved, so testing the rule requires repository and mailer collaborators.

**Positive example**

```php
public function sendReminders(DateTimeImmutable $today): void
{
    $openOrders = $this->orderRepository->findBy(['status' => 'open']);
    $overdueOrders = $this->selectOverdueOrders($openOrders, $today);
    $this->reminders->sendFor($overdueOrders);
}

/** @param list<Order> $orders @return list<Order> */
private function selectOverdueOrders(array $orders, DateTimeImmutable $today): array
{
    return array_values(array_filter(
        $orders,
        static fn (Order $order): bool =>
            $order->dueDate() < $today && !$order->isDisputed(),
    ));
}
```

In this illustration, the repository selects open orders with `findBy(['status' => 'open'])`. The integration method shows the flow while the selection operation holds the decision logic without repository or mail dependencies.

## Single Level of Abstraction

**Intent**

Keep each method’s statements at a consistent conceptual level so readers can understand either the workflow or one detailed operation at a time.

**What to look for during review**

Look for a high-level orchestration method interrupted by array-key manipulation, SQL, serialization details, parsing, or dense calculations.

**Typical violation**

A publishing method coordinates a use case and manually builds and encodes a transport payload in the middle of that flow.

**When the principle should not be applied mechanically**

Do not extract every expression. A helper should name a meaningful lower-level operation or repeated concept, not merely hide an obvious line.

**Negative example**

```php
public function publish(Article $article): void
{
    $this->articlePublicationPolicy->ensurePublishable($article);
    $payload = json_encode([
        'id' => (string) $article->id(),
        'body' => $article->body(),
    ], JSON_THROW_ON_ERROR);
    $this->client->post('/articles', $payload);
}
```

Use-case orchestration is mixed with transport mapping and JSON encoding details.

**Positive example**

```php
public function publish(Article $article): void
{
    $this->articlePublicationPolicy->ensurePublishable($article);
    $payload = $this->createPayload($article);
    $this->client->post('/articles', $payload);
}

private function createPayload(Article $article): string
{
    return json_encode([
        'id' => (string) $article->id(),
        'body' => $article->body(),
    ], JSON_THROW_ON_ERROR);
}
```

The public method now stays at workflow level, while the named helper contains the transport-level detail. Input fields are already validated at the input boundary with submitted values unchanged; the publication policy checks business state, and payload construction preserves the accepted body.

## SRP — Single Responsibility Principle

**Intent**

A module, class, or function should own one cohesive responsibility and have one coherent reason to change.

**What to look for during review**

Look for components that combine independently changing business policy, persistence, formatting, transport, notification, validation, or orchestration.

**Typical violation**

An invoice service validates input, writes SQL, renders a PDF, and sends email.

**When the principle should not be applied mechanically**

Do not equate one responsibility with one method or split a cohesive concept into tiny classes. Orchestration can itself be one responsibility when it coordinates focused collaborators.

**Negative example**

```php
final class InvoiceService
{
    public function issue(Invoice $invoice): void
    {
        $this->validate($invoice);
        $this->pdo->insert('invoices', $invoice->toRow());
        $pdf = $this->renderPdf($invoice);
        $this->mailer->send($invoice->email(), $pdf);
    }
}
```

Validation, storage, document rendering, and delivery change for different reasons but are owned by one class.

**Positive example**

```php
final class InvoiceIssuer
{
    public function __construct(
        private InvoiceIssuancePolicy $invoiceIssuancePolicy,
        private InvoiceRepository $invoiceRepository,
        private InvoiceIssuedPublisher $invoiceIssuedPublisher,
    ) {}

    public function issue(Invoice $invoice): void
    {
        $this->invoiceIssuancePolicy->ensureIssuable($invoice);
        $this->invoiceRepository->save($invoice);
        $this->invoiceIssuedPublisher->publish(new InvoiceIssued($invoice->id()));
    }
}
```

The class owns issuance orchestration, while business-state eligibility, persistence, and post-issuance reactions have focused boundaries. Field validation has already run at the input boundary; the issuance policy does not repeat it.

## SoC — Separation of Concerns

**Intent**

Keep distinct kinds of policy and mechanism in boundaries where each can change without entangling the others.

**What to look for during review**

Look for web, persistence, presentation, business, security, and infrastructure concerns mixed in the same module or code path.

**Typical violation**

An HTTP controller runs SQL, decides business eligibility, and assembles HTML.

**When the principle should not be applied mechanically**

Do not impose layers or folders that the project does not use. Separate concerns at the smallest boundary that makes change and testing clearer.

**Negative example**

```php
public function postLoanApproval(ServerRequestInterface $request): ResponseInterface
{
    $row = $this->pdo->query('SELECT * FROM loans WHERE id = 42')->fetch();
    $approved = $row['score'] >= 700 && $row['debt'] < 10_000;

    return new HtmlResponse('<p>' . ($approved ? 'Approved' : 'Declined') . '</p>');
}
```

Transport, storage, lending policy, and rendering are entangled in one boundary method.

**Positive example**

```php
public function postLoanApproval(
    ApproveLoanRequest $approveLoanRequest,
): ResponseInterface {
    $decision = $this->loanApprovalService->approve($approveLoanRequest);

    return $this->loanDecisionResponseFactory->create($decision);
}
```

Input middleware hydrates and validates `ApproveLoanRequest` before invoking the controller. The controller passes that same DTO to the application service and delegates HTTP output to the response factory; application behavior and response presentation have distinct owners.

## ISP — Interface Segregation Principle

**Intent**

Clients and implementations should depend only on the focused operations they actually need and can honor.

**What to look for during review**

Look for broad interfaces whose implementers stub, ignore, or reject methods, or whose clients receive unrelated capabilities and dependencies.

**Typical violation**

A read-only store implements a combined read/write/export interface and throws for unsupported methods.

**When the principle should not be applied mechanically**

Do not split a small cohesive interface into one-method interfaces without distinct client needs. Cohesion and actual usage define the boundary.

**Negative example**

```php
interface DocumentStore
{
    public function find(DocumentId $id): Document;
    public function save(Document $document): void;
    public function exportPdf(DocumentId $id): string;
}

final class ReadOnlyArchive implements DocumentStore
{
    public function save(Document $document): void
    {
        throw new LogicException('Read only');
    }
}
```

The archive cannot honor the broad contract, and readers depend on capabilities they do not use.

**Positive example**

```php
interface DocumentReader
{
    public function find(DocumentId $id): Document;
}

interface DocumentWriter
{
    public function save(Document $document): void;
}
```

Clients request the capability they need, and a read-only archive can implement its complete contract.

## DIP — Dependency Inversion Principle

**Intent**

Keep high-level policy independent of volatile low-level mechanisms by making dependencies point toward stable, purpose-owned boundaries.

**What to look for during review**

Look for business behavior constructing infrastructure clients, using service locators or globals, or depending directly on third-party and persistence APIs that make policy hard to test or replace.

**Typical violation**

Checkout logic constructs a vendor payment SDK inside the use case.

**When the principle should not be applied mechanically**

Do not add an interface for every class. A stable local concrete collaborator is fine when no meaningful boundary, substitution, or testing need exists.

**Negative example**

```php
final class Checkout
{
    public function pay(Order $order): void
    {
        $gateway = new VendorPaymentClient($_ENV['PAYMENT_KEY']);
        $gateway->charge($order->totalInCents());
    }
}
```

The application policy owns vendor construction and protocol details, coupling checkout to a volatile mechanism.

**Positive example**

```php
interface PaymentGateway
{
    public function charge(Money $amount): PaymentId;
}

final class Checkout
{
    public function __construct(private PaymentGateway $paymentGateway) {}

    public function pay(Order $order): PaymentId
    {
        return $this->paymentGateway->charge($order->total());
    }
}
```

Checkout depends on the capability it needs; vendor adaptation and construction stay at the composition boundary.

## LSP — Liskov Substitution Principle

**Intent**

Every implementation or subtype must preserve the behavioral contract expected through its parent type.

**What to look for during review**

Look for narrowed inputs, weakened results, new ordinary failure modes, ignored operations, required type checks, or callers that special-case an implementation.

**Typical violation**

A subtype inherits a supported operation and throws because that operation does not make sense for it.

**When the principle should not be applied mechanically**

Do not reject inheritance merely because composition is often preferred. Inheritance is appropriate when every subtype honors the full contract and the hierarchy expresses the domain.

**Negative example**

```php
class BankAccount
{
    public function withdraw(Money $amount): void {}
}

final class FixedTermAccount extends BankAccount
{
    public function withdraw(Money $amount): void
    {
        throw new LogicException('Withdrawals are not supported');
    }
}
```

Code accepting `BankAccount` cannot safely substitute `FixedTermAccount` because an ordinary parent operation becomes unsupported.

**Positive example**

```php
abstract class Notification
{
    abstract public function message(): string;
}

final class PasswordResetNotification extends Notification
{
    public function message(): string
    {
        return 'Reset your password';
    }
}
```

The subtype fulfills the complete parent contract and can be used wherever a `Notification` is expected.

## Principle of Least Astonishment

**Intent**

APIs and behavior should match reasonable expectations created by their names, types, conventions, and surrounding code.

**What to look for during review**

Look for hidden side effects in queries, misleading names, surprising nullability, inconsistent units, unusual exception behavior, or methods whose cost differs sharply from what their names imply.

**Typical violation**

A method named `findAll()` mutates records while returning an unexpected nullable collection.

**When the principle should not be applied mechanically**

Expectations depend on established project and framework conventions. Do not replace a familiar local convention merely to match a personal preference.

**Negative example**

```php
/** @return list<Customer>|null */
public function findAll(): ?array
{
    $this->archiveInactiveCustomers();

    return $this->rows ?: null;
}
```

A query-like name hides a write and returns `null` where callers reasonably expect a collection.

**Positive example**

```php
/** @return list<Customer> */
public function findAll(): array
{
    return $this->rows;
}

public function archiveInactive(): void
{
    $this->archiveInactiveCustomers();
}
```

Query and command behavior are explicit, and the collection contract is predictable.

## Information Hiding Principle

**Intent**

Hide volatile representation and implementation decisions behind behavior-focused boundaries so callers do not depend on internals.

**What to look for during review**

Look for public mutable state, leaked database or vendor objects, callers manipulating internal arrays, or interfaces shaped around one implementation’s storage.

**Typical violation**

An order exposes its status field for arbitrary external mutation.

**When the principle should not be applied mechanically**

Do not wrap stable transparent data in ceremony without an invariant or change boundary. Immutable DTOs may intentionally expose their data.

**Negative example**

```php
final class Order
{
    public string $status = 'draft';
}

$order->status = 'paid';
```

Any caller can bypass allowed transitions, and storage representation becomes public API.

**Positive example**

```php
final class Order
{
    private OrderStatus $status = OrderStatus::Draft;

    public function markPaid(): void
    {
        if ($this->status !== OrderStatus::Submitted) {
            throw new LogicException('Only submitted orders can be paid');
        }

        $this->status = OrderStatus::Paid;
    }
}
```

The representation and transition rule stay behind an operation that can preserve the invariant.

## OCP — Open Closed Principle

**Intent**

When real variation is recurring, make new variants addable through a stable boundary without repeatedly modifying central policy.

**What to look for during review**

Look for repeated or growing conditionals over the same type or capability across several modules, especially when variants change independently.

**Typical violation**

Every report format requires another branch in multiple central switches.

**When the principle should not be applied mechanically**

Do not create strategies, plugins, registries, or factories for one stable conditional or an imagined future variant. KISS and YAGNI take precedence until variation is credible.

**Negative example**

```php
public function export(Report $report, string $format): string
{
    return match ($format) {
        'csv' => $this->toCsv($report),
        'json' => $this->toJson($report),
        'xml' => $this->toXml($report),
    };
}
```

If format-specific branches recur throughout the system and formats evolve independently, each new format requires edits to central code.

**Positive example**

```php
interface ReportExporter
{
    public function export(Report $report): string;
}

final class CsvReportExporter implements ReportExporter
{
    public function export(Report $report): string
    {
        return $this->encodeRows($report->rows());
    }
}
```

With established format variation, a new exporter can be added behind the existing boundary without changing export policy.

## Tell, Don't Ask

**Intent**

Ask an object to perform behavior it owns instead of pulling out its state and making its decisions elsewhere.

**What to look for during review**

Look for callers that inspect an object’s status or internals, decide a transition, then write state back through setters.

**Typical violation**

A service checks whether an order is a draft before setting its status to submitted.

**When the principle should not be applied mechanically**

Queries are valid for presentation, reporting, and decisions owned by another policy. Do not move behavior to an object that lacks the information or responsibility needed to decide it.

**Negative example**

```php
if ($order->status() === OrderStatus::Draft && $order->lineCount() > 0) {
    $order->setStatus(OrderStatus::Submitted);
}
```

The caller owns the order’s transition rule and can bypass it elsewhere.

**Positive example**

```php
$order->submit();
```

`Order::submit()` can protect the transition and keep the rule with the state it governs.

## LoD — Law of Demeter

**Intent**

Limit a component’s knowledge of collaborators’ internal object graphs; communicate through its direct collaborators and purpose-revealing operations.

**What to look for during review**

Look for long navigation chains, repeated traversal through nested objects, or changes in one object graph that ripple into unrelated callers.

**Typical violation**

A shipping service reaches through order, customer, address, and country to obtain a code.

**When the principle should not be applied mechanically**

Do not add forwarding methods for every harmless value traversal. Immutable DTOs, builders, and fluent APIs can legitimately support chains when their contract is the chain itself.

**Negative example**

```php
$countryCode = $order->customer()->address()->country()->code();
```

The caller depends on several internal relationships and breaks when that object graph changes.

**Positive example**

```php
$countryCode = $order->shippingCountryCode();
```

The caller asks its direct collaborator for the concept it needs while the order hides how shipping information is organized.

## Implementation Reflects Design

**Intent**

Make important architectural and domain decisions visible in source structure, names, dependencies, and control flow so the implementation tells the same story as the intended design.

**What to look for during review**

Compare stated responsibilities and boundaries with actual names and dependencies. Look for important policies hidden in controllers, generic helpers, conditionals, or misplaced modules despite a different documented design.

**Typical violation**

The design names a refund policy, but its rules are anonymous conditionals scattered through transport code.

**When the principle should not be applied mechanically**

Do not create a class for every noun in a diagram or preserve obsolete documentation in code. The implementation should express current meaningful decisions at proportionate scale.

**Negative example**

```php
public function refund(Order $order): void
{
    if ($order->status()->value === 'paid' && $order->paidAt() > new DateTimeImmutable('-30 days')) {
        $this->payments->refund($order->paymentId());
    }
}
```

The promised refund policy is hidden as an inline transport-level condition with no design name or boundary.

**Positive example**

```php
public function refund(Order $order): void
{
    $this->refundPolicy->ensureRefundable($order, $this->clock->now());
    $this->payments->refund($order->paymentId());
}
```

The implementation visibly contains the policy named by the design and keeps orchestration separate from its decision.

## YAGNI — You Ain’t Gonna Need It

**Intent**

Implement today’s requirements and defer optional flexibility until evidence shows it is needed.

**What to look for during review**

Look for unused extension points, speculative configuration, versioning, factories with one product, interfaces with one foreseeable caller, and branches for impossible states.

**Typical violation**

A single fixed export path includes a plugin registry and versioned strategy selection for hypothetical formats.

**When the principle should not be applied mechanically**

Do not remove capabilities required by an accepted requirement, external contract, known near-term change, security boundary, or migration path merely because they are not exercised locally yet.

**Negative example**

```php
final class ExporterFactory
{
    /** @param array<string, array<int, Exporter>> $versions */
    public function __construct(private array $versions) {}

    public function create(string $format, int $version = 1): Exporter
    {
        return $this->versions[$format][$version];
    }
}
```

When the only requirement is one CSV export, unused format and version flexibility adds concepts, configuration, and failure paths.

**Positive example**

```php
final class CsvExporter
{
    public function export(Report $report): string
    {
        return $this->encodeRows($report->rows());
    }
}
```

The implementation directly serves the present requirement and leaves room to introduce a real boundary when another format is approved.

## Principle Relationships

- SRP and SoC both seek focused change boundaries. SRP asks whether one unit has one cohesive reason to change; SoC also examines separation between broader kinds of policy and mechanism.
- DRY and YAGNI can pull in opposite directions. Remove duplicated knowledge when it is truly shared, but tolerate provisional similarity until a stable abstraction is visible.
- KISS and YAGNI are counterweights to speculative applications of OCP, DIP, SRP, and patterns in general.
- DIP and OCP often reinforce one another when stable policy needs protection from real infrastructure or variant churn.
- ISP can reduce coupling introduced by broad abstractions created under DIP.
- Tell, Don't Ask, LoD, and Information Hiding often reveal the same encapsulation problem from different angles. Choose the principle that best explains the consequence rather than listing all three.
- Single Level of Abstraction often exposes a method that mixes high-level orchestration with low-level detail. IOSP more specifically distinguishes coordination and side effects from operational decision logic.
- FCoI and LSP distinguish reuse-driven inheritance from a legitimate substitutable hierarchy.
- Information Hiding supports OCP by allowing implementations to change behind stable behavior-focused boundaries.
- Implementation Reflects Design checks the result of all the other decisions: important responsibilities, policies, and dependency directions should remain visible in the source.
