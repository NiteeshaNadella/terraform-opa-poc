
package terraform.tags

import rego.v1

required_tags := {
    "environment",
    "project",
    "owner",
    "costcenter"
}

deny contains msg if {
    some resource in input.resource_changes

    resource.type == "azurerm_resource_group"
    resource.change.actions[_] == "create"

    tags := object.get(resource.change.after, "tags", {})

    some tag in required_tags
    value := object.get(tags, tag, "")

    trim(value, " ") == ""

    msg := sprintf("Resource %s is missing required tag: %s", [
        resource.address,
        tag
    ])
}

default allow := false

allow if {
    count(deny) == 0
}
