# Localized Email Body Examples

Use these examples when an application owns localized email copy in source control. Adapt names and template syntax to the engine already established by the project.

## Replace Line Assembly With A Complete Template

Avoid assembling translated paragraphs in a factory:

~~~php
$intro = $this->translator->trans(
    'Confirm the email address for your account by opening this link:',
    locale: $locale->value,
);
$validity = $this->translator->trans(
    'This link is valid for 24 hours and can be used once.',
    locale: $locale->value,
);
$textBody = implode("\n", [$intro, '', $verificationUrl, '', $validity]) . "\n";
~~~

When several email families follow the same filename convention, represent the locale-independent names with an application-owned enum and resolve the locale-qualified path in one shared renderer:

~~~php
enum EmailBodyTemplate: string
{
    case AccountEmailVerification = 'account-email-verification';
    case OwnerApprovalApproved = 'owner-approval-approved';
    case OwnerApprovalRejected = 'owner-approval-rejected';
    case InquiryAcknowledgment = 'inquiry-acknowledgment';
}

final class LocalizedEmailBodyRenderer
{
    public function __construct(private PhpRenderer $templates)
    {
    }

    /** @param array<string, mixed> $templateData */
    public function render(
        EmailBodyTemplate $template,
        Locale $locale,
        array $templateData = [],
    ): string {
        $templateName = sprintf(
            'emails/%s.%s.php',
            $template->value,
            $locale->value,
        );
        $templateData['locale'] = $locale;

        return $this->templates->fetch($templateName, $templateData);
    }
}

final class AccountEmailVerificationEmailFactory
{
    public function __construct(
        private TranslatorInterface $translator,
        private LocalizedEmailBodyRenderer $emailBodyRenderer,
    ) {
    }

    public function create(
        string $recipient,
        Locale $locale,
        string $verificationUrl,
    ): OutgoingEmail {
        $subject = $this->translator->trans(
            'Verify your email address',
            locale: $locale->value,
        );
        $textBody = $this->emailBodyRenderer->render(
            EmailBodyTemplate::AccountEmailVerification,
            $locale,
            [
                'verificationUrl' => $verificationUrl,
            ],
        );

        return new OutgoingEmail(
            $recipient,
            'Example – ' . $subject,
            $textBody,
        );
    }
}
~~~

Place `LocalizedEmailBodyRenderer` with application presentation or email composition when the project uses App/Domain/Infrastructure boundaries without an explicit Clean Architecture rule. Keep template-engine construction and configuration in Infrastructure, and keep all rendering concerns out of Domain.

The shared renderer calls `PhpRenderer::fetch()`, which renders to a string without the configured layout by default. Pass false explicitly only when it clarifies a project-specific wrapper or convention; do not disable and restore the shared layout around the call.

The complete German template contains its own prose and formatting:

~~~php
<?php

/** @var string $verificationUrl */
?>
Bestätigen Sie die E-Mail-Adresse Ihres Kontos über diesen Link:

<?= $verificationUrl ?>

Dieser Link ist 24 Stunden gültig und kann einmal verwendet werden.
Falls Sie keinen Zugang beantragt haben, können Sie diese E-Mail ignorieren.
~~~

The English file contains the complete English body in the same structure. The URL is generated application data and is emitted without HTML escaping because the output is plain text.

## Separate Message Outcomes

Give each outcome its own complete file:

~~~text
emails/
├── owner-approval-approved.de.php
├── owner-approval-approved.en.php
├── owner-approval-rejected.de.php
├── owner-approval-rejected.en.php
├── owner-approval-correction-requested.de.php
└── owner-approval-correction-requested.en.php
~~~

The purpose-specific factory selects the outcome as a subject message and `EmailBodyTemplate` case. The shared renderer adds the locale-qualified filename:

~~~php
[$subjectMessage, $bodyTemplate] = match ($decision) {
    ApprovalDecision::Approve => [
        'Your access was approved',
        EmailBodyTemplate::OwnerApprovalApproved,
    ],
    ApprovalDecision::Reject => [
        'Your access was rejected',
        EmailBodyTemplate::OwnerApprovalRejected,
    ],
};
~~~

Do not put an approval-decision match or if around different paragraphs inside one localized template. Conditions for optional data within one outcome remain appropriate.

## Pass Structured Presentation Data

Use a typed presentation model when a body has several related dynamic values:

~~~php
final readonly class InquiryEmailViewModel
{
    public function __construct(
        public string $firstName,
        public string $lastName,
        public string $arrivalDate,
        public string $departureDate,
        public int $adults,
        public int $children,
        public ?string $notes,
    ) {
    }
}
~~~

Pass the model and locale through the shared email-body renderer:

~~~php
$textBody = $this->emailBodyRenderer->render(
    EmailBodyTemplate::InquiryAcknowledgment,
    $locale,
    ['email' => $emailViewModel],
);
~~~

A locale-specific template owns its prose, labels, greeting, optional-section placement, and signature. It may use _t() for the small ICU fragment whose grammar depends on counts:

~~~php
<?php

/** @var InquiryEmailViewModel $email */
/** @var callable(string, array<string, mixed>): string $_t */
?>
Guten Tag <?= $email->firstName ?> <?= $email->lastName ?>,

vielen Dank für Ihre Anfrage.

Anreise: <?= $email->arrivalDate ?>
Abreise: <?= $email->departureDate ?>
Personen: <?= $_t(
    '{adults, plural, one {# adult} other {# adults}}{children, plural, =0 {} one {, # child} other {, # children}}',
    ['adults' => $email->adults, 'children' => $email->children],
) ?>
<?php if ($email->notes !== null): ?>

Ihre Anmerkung:
<?= $email->notes ?>
<?php endif ?>

Mit freundlichen Grüßen
Ihr Team
~~~

Do not wrap plain-text values with the HTML escaping helper. The application must still validate or normalize external values according to its input-boundary rules before they reach email composition.

## Verify Recipient-Visible Output

Render with the real template engine and assert the complete body for every locale and outcome:

~~~php
#[Test]
#[DataProvider('localizedBodyProvider')]
public function givenLocale_shouldRenderCompleteEmailBody(
    Locale $locale,
    string $expectedTextBody,
): void {
    $factory = $this->createFactoryWithRealTemplates();

    $actual = $factory->create(
        'owner@example.com',
        $locale,
        'https://example.com/verify/opaque-token',
    );

    self::assertSame($expectedTextBody, $actual->textBody);
}
~~~

Complete-body assertions protect punctuation, paragraph ordering, optional-section spacing, dynamic-value placement, and the final newline together. When a shared filename convention is used, cover every applicable `EmailBodyTemplate` and `Locale::cases()` combination so a new locale exposes missing templates. Test delivery orchestration separately so those tests do not depend on template filenames or renderer call sequences.
