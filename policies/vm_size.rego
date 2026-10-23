package terraform.vm_size

import rego.v1

approved_sizes := {"Standard_B1s", "Standard_B1ms"}

# Validate the common exemption requirements.
valid_exemption(exemption, address, size) if {
    exemption.policy == "vm_size"
    exemption.resource == address
    exemption.approved_size == size

    is_string(exemption.reason)
    trim(exemption.reason, " ") != ""

    is_string(exemption.ticket)
    trim(exemption.ticket, " ") != ""

    is_string(exemption.expires_at)
    expiry := time.parse_rfc3339_ns(exemption.expires_at)
    expiry > time.now_ns()
}

# Application-specific exemption.
# The application must match the context supplied to OPA.
exempted(address, size) if {
    some exemption in data.exemptions

    valid_exemption(exemption, address, size)

    application := data.application_context.id
    exemption.application == application
}

# Backward compatibility for the original single-application POC.
# Legacy exemptions apply only when no application context is loaded.
exempted(address, size) if {
    some exemption in data.exemptions

    valid_exemption(exemption, address, size)

    not data.application_context.id
    not exemption.application
}

# Identify unapproved VM sizes without valid exemptions.
deny contains msg if {
    some rc in input.resource_changes

    rc.type == "azurerm_linux_virtual_machine"
    rc.change.actions[_] == "create"

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