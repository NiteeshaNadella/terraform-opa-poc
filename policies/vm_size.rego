
package terraform.vm_size

import rego.v1

approved_sizes := {"Standard_B1s", "Standard_B1ms"}

# Validate an approved exemption.
valid_exemption(exemption, address, size) if {
    exemption.policy == "vm_size"
    exemption.resource == address
    exemption.approved_size == size

    is_string(exemption.application)
    exemption.application != ""

    is_string(exemption.reason)
    trim(exemption.reason, " ") != ""

    is_string(exemption.ticket)
    trim(exemption.ticket, " ") != ""

    is_string(exemption.expires_at)
    expiry := time.parse_rfc3339_ns(exemption.expires_at)
    expiry > time.now_ns()
}

# Match exemption to the application being validated.
exempted(address, size) if {
    application := data.application_context.id
    is_string(application)
    application != ""

    some exemption in data.exemptions

    valid_exemption(exemption, address, size)
    exemption.application == application
}

# Reject unapproved Linux and Windows VM sizes.
# Applies to both resource creation and updates.
deny contains msg if {
    some rc in input.resource_changes

    rc.type in {
        "azurerm_linux_virtual_machine",
        "azurerm_windows_virtual_machine"
    }

    some action in rc.change.actions
    action in {"create", "update"}

    size := rc.change.after.size

    not size in approved_sizes
    not exempted(rc.address, size)

    msg := sprintf(
        "VM %s uses an unapproved size: %s",
        [rc.address, size]
    )
}

default allow := false

allow if {
    count(deny) == 0
}
