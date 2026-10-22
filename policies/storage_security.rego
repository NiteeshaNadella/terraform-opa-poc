
package terraform.storage_security

import rego.v1

deny contains msg if {
    some rc in input.resource_changes
    rc.type == "azurerm_storage_account"
    rc.change.actions[_] == "create"

    rc.change.after.allow_nested_items_to_be_public != false

    msg := sprintf(
        "Storage account %s must disable public blob access",
        [rc.address]
    )
}

default allow := false

allow if {
    count(deny) == 0
}