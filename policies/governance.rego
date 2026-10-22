
package terraform.governance

import rego.v1

# Collect mandatory tag violations
deny contains msg if {
    data.terraform.tags.allow == false
    msg := "Mandatory tags policy failed"
}

# Collect VM size violations
deny contains msg if {
    some violation in data.terraform.vm_size.deny
    msg := violation
}

# Collect Storage Account violations
deny contains msg if {
    some violation in data.terraform.storage_security.deny
    msg := violation
}

# Final decision
default allow := false

allow if {
    data.terraform.tags.allow == true
    data.terraform.vm_size.allow == true
    data.terraform.storage_security.allow == true
    count(deny) == 0
}
