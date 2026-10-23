# Terraform Infrastructure Governance Using OPA and GitHub Actions

## 1. Project Overview

This project demonstrates the implementation of **Open Policy Agent (OPA)** for validating Azure infrastructure configurations created using Terraform.

OPA policies are integrated into a GitHub Actions workflow to enforce infrastructure governance and compliance requirements before infrastructure deployment.

**The POC implements three governance policies:**

1. Mandatory resource tags
2. Approved Azure Virtual Machine sizes
3. Azure Storage Account public access restrictions

It also demonstrates a policy exemption mechanism that permits specifically documented exceptions while ensuring that other non-exempted policy violations continue to fail the pipeline.

### Objectives

- Implement OPA policies using Rego.
- Validate Terraform execution plans converted into JSON.
- Enforce infrastructure governance through GitHub Actions.
- Implement resource-specific policy exemptions.
- Demonstrate successful and failed pipeline executions.
- Ensure policy violations produce a nonzero pipeline exit code.

**Scope:** This POC generates and validates Terraform plans. It does not execute `terraform apply` or deploy infrastructure.

---

## 2. OPA and Rego

Open Policy Agent

Open Policy Agent is an open-source, general-purpose policy engine used to make policy decisions based on structured data.

OPA separates policy decisions from the applications and infrastructure configurations being evaluated.

Rego

Rego is the declarative policy language used by OPA.

It allows engineers to define rules that evaluate structured input such as JSON.

### Important Rego Concepts

**Package**

Groups related rules under a namespace.

Example:

`package terraform.vm_size`

**Input**

Represents the data being evaluated.

In this project, the input is the Terraform execution plan converted to JSON.

**Data**

Represents information loaded into OPA, including policies and exemption configuration.

**Allow**

Returns a Boolean decision indicating whether the configuration satisfies the policy.

**Deny**

Reports policy violations, including information about the affected resources.

**Default decision**

A rule such as `default allow := false` establishes a default rejection decision until the allow conditions are satisfied.

### Terraform Plan-JSON

Terraform creates an execution plan describing proposed infrastructure changes.

OPA cannot directly evaluate Terraform HCL as a Terraform execution plan. Instead, the plan is converted to JSON, allowing Rego rules to inspect resource attributes.

---

## 3. Repository Structure

```text
terraform-opa-poc/
├── .github/
│   └── workflows/
│       └── terraform-opa.yml
├── policies/
│   ├── policy.rego
│   ├── vm_size.rego
│   ├── storage_security.rego
│   └── governance.rego
├── main.tf
├── exemptions.json
├── .terraform.lock.hcl
├── .gitignore
└── README.md
```

### File Descriptions

| File | Description |
|---|---|
| `main.tf` | Defines the Azure infrastructure |
| `policy.rego` | Validates mandatory resource tags |
| `vm_size.rego` | Validates approved Linux VM sizes and exemptions |
| `storage_security.rego` | Restricts public blob access |
| `governance.rego` | Combines policy decisions |
| `exemptions.json` | Defines documented policy exceptions |
| `terraform-opa.yml` | GitHub Actions workflow |
| `README.md` | POC documentation |

---

## 4. OPA Policy Implementation

### Policy 1 — Mandatory Resource Tags

**Objective:** Ensure applicable Azure resources have the required governance tags.

Required tags:

- `environment`
- `project`
- `owner`
- `costcenter`

Example compliant configuration:

```hcl
tags = {
  environment = "dev"
  project     = "opa-poc"
  owner       = "niteesha"
  costcenter  = "IT001"
}
```

**PASS scenario:** All required tags are present.

**FAIL scenario:** A required tag, such as `costcenter`, is missing.

This policy supports resource identification, ownership, environment management, and cost allocation.

#### Commands to Validate Mandatory Tags

**Check whether all required tags are present:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.tags.allow'
```

Expected result when all required tags exist:

```text
true
```

Expected result when a required tag is missing:

```text
false
```

**Display mandatory tag violations:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.tags.deny'
```

If the configuration complies with the policy, no violations should be reported.

If a required tag is missing, OPA reports the violation according to the rules defined in `policy.rego`.

---

### Policy 2 — Approved VM Sizes

**Objective:** Restrict the size of newly created Azure Linux VMs to an approved list.

Approved sizes:

```rego
approved_sizes := {"Standard_B1s", "Standard_B1ms"}
```

**PASS scenario:**

```hcl
size = "Standard_B1s"
```

**FAIL scenario:**

```hcl
size = "Standard_D8s_v5"
```

**An unapproved size creates a policy violation unless a matching valid exemption exists.**

The current POC rule targets newly created Azure Linux VMs. Additional resource types and update actions can be incorporated into future versions.

#### Commands to Validate VM Sizes

**Evaluate the VM size allow decision:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.vm_size.allow'
```

Expected result for an approved VM size:

```text
true
```

Expected result for an unapproved VM size without an exemption:

```text
false
```

**Display VM size violations:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.vm_size.deny'
```

Example violation:

```text
VM azurerm_linux_virtual_machine.example uses an unapproved size: Standard_D8s_v5
```

If no violations exist, OPA returns:

```json
[]
```

---

### Policy 3 — Storage Account Security

**Objective:** Prevent Azure Storage Accounts from allowing anonymous public blob access.

Compliant configuration:

```hcl
allow_nested_items_to_be_public = false
```

Noncompliant configuration:

```hcl
allow_nested_items_to_be_public = true
```

**PASS scenario:** Public blob access is disabled.

**FAIL scenario:** Public blob access is permitted.

This policy helps reduce the risk of unintended public exposure of stored data.

#### Commands to Validate Storage Account Security

**Evaluate the Storage Account allow decision:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.storage_security.allow'
```

Expected result for a compliant Storage Account:

```text
true
```

Expected result when public blob access is permitted:

```text
false
```

**Display Storage Account violations:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.storage_security.deny'
```

Example violation:

```text
Storage account azurerm_storage_account.example must disable public blob access
```

For a compliant configuration:

```json
[]
```

---

## 5. Policy Exemption Mechanism

Some infrastructure requirements may justify temporary exceptions to governance policies.

For example, a development team may require a larger VM for performance testing.

The POC implements a resource-specific exemption using `exemptions.json`.

### Example Exemption

```json
{
  "exemptions": [
    {
      "policy": "vm_size",
      "resource": "azurerm_linux_virtual_machine.example",
      "approved_size": "Standard_D8s_v5",
      "reason": "Temporary performance testing",
      "ticket": "CHG-1001",
      "expires_at": "2026-10-30T23:59:59Z"
    }
  ]
}
```

CHG-1001 is an illustrative approval reference used for this demonstration.

### Exemption Validation

The VM policy checks:

1. Policy name matches.
2. Terraform resource address matches.
3. VM size matches the exempted value.
4. A reason is provided.
5. A ticket reference is provided.
6. The exemption has not expired.

If these conditions are satisfied, the specific VM size violation is exempted.

The exemption does not automatically permit unrelated infrastructure violations.

### Commands to Test Policy Exemptions

For this demonstration, the Terraform configuration contains:

```hcl
size = "Standard_D8s_v5"
```

This size is outside the approved list.

#### Scenario 1 — Unapproved VM Without Exemption

Evaluate the VM policy without loading `exemptions.json`:

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.vm_size.allow'
```

Expected result:

```text
false
```

Display the violation:

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.vm_size.deny'
```

Expected violation:

```text
VM azurerm_linux_virtual_machine.example uses an unapproved size: Standard_D8s_v5
```

#### Scenario 2 — Unapproved VM With Valid Exemption

Evaluate the same Terraform plan while loading the exemption file:

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.vm_size.allow'
```

Expected result:

```text
true
```

Display any remaining VM size violations:

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.vm_size.deny'
```

Expected result:

```json
[]
```

This demonstrates that the matching exemption permits the specific unapproved VM size.

#### Scenario 3 — Expired or Nonmatching Exemption

If an exemption has expired, references another resource, or specifies a different VM size, it will not satisfy the exemption conditions.

The same evaluation command should then return:

```text
false
```

### Important Limitation

The POC validates the structure, matching conditions, and expiration of an exemption record. It does not independently verify that the referenced change ticket was approved in an external change-management system.

A production solution should integrate exemption approval with an authorized governance process.

---

## 6. Centralized Governance

The `governance.rego` policy combines the decisions from the three individual governance policies.

The combined decision permits a Terraform plan only when all applicable policy requirements are satisfied or validly exempted.

Example:

| Policy | Result |
|---|---|
| Mandatory tags | PASS |
| VM size with valid exemption | PASS |
| Storage Account security | FAIL |
| **Overall governance** | **FAIL** |

This ensures that an exemption for one resource does not bypass unrelated security policies.

### Commands to Evaluate Combined Governance

**Evaluate the final governance allow decision:**

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.governance.allow'
```

Expected result when all policies pass or have valid exemptions:

```text
true
```

Expected result when a non-exempted violation exists:

```text
false
```

**Display all outstanding governance violations:**

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.governance.deny'
```

Example result when Storage Account security is violated:

```json
[
  "Storage account azurerm_storage_account.example must disable public blob access"
]
```

For a compliant Terraform plan:

```json
[]
```

### Local Terraform and OPA Execution

Run the following commands from the root directory of the repository.

#### Step 1 — Initialize Terraform

```powershell
terraform init
```

#### Step 2 — Validate Terraform

```powershell
terraform validate
```

#### Step 3 — Generate the Terraform Plan

```powershell
terraform plan -out="plan.tfplan"
```

#### Step 4 — Convert the Plan to JSON

```powershell
terraform show -json plan.tfplan > plan.tfplan.json
```

#### Step 5 — Validate Rego Policies

```powershell
opa check policies
```

#### Step 6 — Evaluate Combined Governance

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.governance.allow'
```

#### Step 7 — Display Policy Violations

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.governance.deny'
```

#### Step 8 — Check the Individual Policies

**Mandatory tags:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.tags.allow'
```

**VM sizes:**

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.vm_size.allow'
```

**Storage security:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.storage_security.allow'
```

#### Step 9 — Check All Policy Violations

**Mandatory tags:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.tags.deny'
```

**VM sizes:**

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.vm_size.deny'
```

**Storage security:**

```powershell
opa eval --format pretty --data policies --input plan.tfplan.json 'data.terraform.storage_security.deny'
```

**Combined governance:**

```powershell
opa eval --format pretty --data policies --data exemptions.json --input plan.tfplan.json 'data.terraform.governance.deny'
```

**These commands were tested locally before integration with GitHub Actions.**

---

## 7. GitHub Actions Integration

The workflow is configured in:

`.github/workflows/terraform-opa.yml`

### Pipeline Steps

1. Checkout repository
2. Install Terraform
3. Authenticate to Azure using GitHub OIDC
4. Initialize Terraform
5. Validate Terraform configuration
6. Generate Terraform execution plan
7. Convert plan to JSON
8. Install OPA
9. Validate Rego policies
10. Display governance violations
11. Enforce the overall governance decision

### Pipeline Failure Handling

The workflow evaluates the final governance decision.

If the decision is `true`, the workflow completes successfully.

If the decision is `false`, the enforcement step explicitly exits with code `1`.

This ensures non-exempted policy violations fail the GitHub Actions job.

### GitHub Actions Enforcement Command

The following shell script is used in the GitHub Actions workflow:

```bash
decision=$(opa eval \
  --format raw \
  --data policies \
  --data exemptions.json \
  --input plan.tfplan.json \
  'data.terraform.governance.allow')

echo "OPA Governance Decision: $decision"

if [ "$decision" != "true" ]; then
  echo "OPA policy validation FAILED"
  exit 1
fi

echo "OPA policy validation PASSED"
```

When OPA returns `true`, the command completes successfully with exit code `0`.

When OPA returns `false`, the script explicitly exits with code `1`, causing the GitHub Actions job to fail.

The explicit shell exit-code check ensures that a policy rejection cannot be mistaken for successful pipeline execution.

---

## 8. Test Scenarios and Results

| Scenario | Expected result | Observed result |
|---|---|---|
| Approved VM size and secure Storage Account | PASS | PASS |
| Unapproved VM without exemption | FAIL | FAIL locally |
| Unapproved VM with valid matching exemption | PASS | PASS |
| Exempted VM with separate Storage Account violation | FAIL | FAIL in GitHub Actions |
| Secure Storage Account restored | PASS | PASS in GitHub Actions |

### Scenario A — Successful GitHub Actions Validation

The Terraform plan contains a VM size exception supported by a matching exemption record.

The Storage Account has public blob access disabled.

OPA returns:

```text
OPA Governance Decision: true
OPA policy validation PASSED
```

### Scenario B — Failed GitHub Actions Validation

The VM exemption remains valid, but the Storage Account configuration permits public blob access.

OPA reports:

```text
Storage account azurerm_storage_account.example must disable public blob access
```

The pipeline returns:

```text
OPA Governance Decision: false
OPA policy validation FAILED
Error: Process completed with exit code 1.
```

---

## 9. Conclusion

This POC demonstrates how Open Policy Agent can be integrated with Terraform and GitHub Actions to enforce Azure infrastructure governance.

Three OPA policies validate mandatory resource tags, approved VM sizes, and Storage Account security settings.

The exemption mechanism supports narrowly scoped exceptions while preserving enforcement of unrelated policies.

Successful and failed GitHub Actions executions confirm that the workflow can approve compliant Terraform plans and reject non-exempted governance violations before infrastructure deployment.
