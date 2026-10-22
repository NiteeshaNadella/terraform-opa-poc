
package terraform.vm_size

import rego.v1

approved_sizes := {"Standard_B1s", "Standard_B1ms"}

# Validate a specific VM exemption
exempted(address, size) if {
    some exemption in data.exemptions

    exemption.policy == "vm_size"
    exemption.resource == address
    exemption.approved_size == size

    exemption.reason != ""
    exemption.ticket != ""

    expiry := time.parse_rfc3339_ns(exemption.expires_at)
    expiry > time.now_ns()
}

# Identify unapproved VM sizes
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
