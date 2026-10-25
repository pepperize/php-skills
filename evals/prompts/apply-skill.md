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

Task:
{{ task }}

{% if project_instructions %}
Project instructions:
{{ project_instructions }}
{% endif %}

{% if code %}
Code:
```php
{{ code }}
```
{% endif %}

Apply only rules supported by the supplied skills and project instructions. Do not invent project constraints.
If the skill is not activated for this project, say so and do not introduce its patterns speculatively.

Respond with:
- Applicable rules: brief bullets
- Result: the requested code, review, questions, or recommendation
