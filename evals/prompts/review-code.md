You are evaluating whether a PHP agent skill is followed.

Skill:
{{ skill }}

{% if additional_skill %}
Additional skill:
{{ additional_skill }}
{% endif %}
{% if api_rules %}
Authoritative API rules:
{{ api_rules }}
{% endif %}
{% if naming_rules %}
Authoritative naming rules:
{{ naming_rules }}
{% endif %}
{% if validation_rules %}
Authoritative input rules:
{{ validation_rules }}
{% endif %}
{% if presentation_rules %}
Authoritative presentation rules:
{{ presentation_rules }}
{% endif %}
{% if task %}
Task:
{{ task }}
{% endif %}
{% if project_instructions %}
Project instructions:
{{ project_instructions }}
{% endif %}

Code:
```php
{{ code }}
```

Review the code only against the supplied skills, owner rules, task, and project instructions. Do not invent unrelated project constraints.
Identify violations, explain why each violates the skill, and propose a concise fix. If there are no violations, respond with a concise no-findings statement and do not name principles that passed, did not apply, or were considered.
