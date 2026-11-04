
package terraform.governance

import rego.v1

# Require a valid application context.
valid_application if {
    application := data.application_context.id
    is_string(application)
    trim(application, " ") != ""
}

# Reject missing application identity.
deny contains msg if {
    not valid_application
    msg := "Application identity is missing or invalid"
}

# Collect mandatory tag violations.
deny contains msg if {
    data.terraform.tags.allow == false
    msg := "Mandatory tags policy failed"
}

# Collect VM size violations.
deny contains msg if {
    some violation in data.terraform.vm_size.deny
    msg := violation
}

# Collect storage security violations.
deny contains msg if {
    some violation in data.terraform.storage_security.deny
    msg := violation
}

# Final governance decision.
default allow := false

allow if {
    valid_application
    data.terraform.tags.allow == true
    data.terraform.vm_size.allow == true
    data.terraform.storage_security.allow == true
    count(deny) == 0
}
