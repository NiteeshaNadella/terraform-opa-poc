
package terraform.storage_security

import rego.v1

# Validate storage account exemptions for the correct application.
valid_exemption(resource_address) if {
    some ex in data.exemptions

    ex.policy == "storage_security"
    ex.resource == resource_address

    # Exemption must belong to the calling application
    application := data.application_context.id
    ex.application == application

    is_string(ex.reason)
    trim(ex.reason, " ") != ""

    is_string(ex.ticket)
    trim(ex.ticket, " ") != ""

    is_string(ex.expires_at)
    expiry := time.parse_rfc3339_ns(ex.expires_at)
    expiry > time.now_ns()
}

# Preserve original POC exemptions without application context.
valid_exemption(resource_address) if {
    some ex in data.exemptions

    ex.policy == "storage_security"
    ex.resource == resource_address

    not data.application_context.id
    not ex.application

    is_string(ex.reason)
    trim(ex.reason, " ") != ""

    is_string(ex.ticket)
    trim(ex.ticket, " ") != ""

    is_string(ex.expires_at)
    expiry := time.parse_rfc3339_ns(ex.expires_at)
    expiry > time.now_ns()
}

# Reject public blob access without a valid exemption.
deny contains msg if {
    some resource in input.resource_changes

    resource.type == "azurerm_storage_account"

    some action in resource.change.actions
    action in {"create", "update"}

    resource.change.after.allow_nested_items_to_be_public == true

    not valid_exemption(resource.address)

    msg := sprintf(
        "Storage account %s allows public blob access",
        [resource.address]
    )
}

default allow := false

allow if {
    count(deny) == 0
}
