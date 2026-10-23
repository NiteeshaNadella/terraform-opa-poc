
package terraform.tags

import rego.v1

required_tags := {
    "environment",
    "project",
    "owner",
    "costcenter"
}

# A matching exemption must identify the resource and missing tag.
# It also requires a reason, ticket, and a future expiry date.
valid_exemption(resource_address, missing_tag) if {
    some ex in data.exemptions

    ex.policy == "tags"
    ex.resource == resource_address
    ex.tag == missing_tag

    is_string(ex.reason)
    trim(ex.reason, " ") != ""

    is_string(ex.ticket)
    trim(ex.ticket, " ") != ""

    is_string(ex.expires_at)
    expiry := time.parse_rfc3339_ns(ex.expires_at)
    expiry > time.now_ns()
}

# Report missing tags unless a valid exemption exists.
deny contains msg if {
    some resource in input.resource_changes

    resource.type in {
        "azurerm_resource_group",
        "azurerm_storage_account"
    }

    some action in resource.change.actions
    action in {"create", "update"}

    tags := object.get(resource.change.after, "tags", {})

    some tag in required_tags
    value := object.get(tags, tag, "")

    trim(value, " ") == ""

    not valid_exemption(resource.address, tag)

    msg := sprintf(
        "Resource %s is missing required tag: %s",
        [resource.address, tag]
    )
}

default allow := false

allow if {
    count(deny) == 0
}
