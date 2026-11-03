# Terraform Infrastructure Governance Using OPA and GitHub Actions

## 1. Project Overview

This project demonstrates the implementation of **Open Policy Agent (OPA)** for validating Azure infrastructure configurations created using Terraform.

OPA policies are integrated into a GitHub Actions workflow to enforce infrastructure governance and compliance requirements before infrastructure deployment.

<img width="537" height="435" alt="image" src="https://github.com/user-attachments/assets/560ed3d8-342a-463c-8eb5-a143bed1ca34" />

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


**Here are screenshots of Some Policy changes:**

Policy Passed= Tags

<img width="1352" height="685" alt="image" src="https://github.com/user-attachments/assets/e86b6763-cbc6-4e26-a5e3-93a450feaf09" />

Policy Failed= Tags

<img width="1344" height="678" alt="image" src="https://github.com/user-attachments/assets/80d0ce14-2c80-4615-baec-083a7dd5d751" />

Blob Access Disabled- Pass

<img width="1341" height="683" alt="image" src="https://github.com/user-attachments/assets/8101868b-c23a-4273-95fc-5d3bcb1eeee6" />

Blob Access permitted- Failed under policy

<img width="1339" height="694" alt="image" src="https://github.com/user-attachments/assets/4db629a4-1100-43ed-afb1-a3954fe274e9" />

Policy Failed due to Unapproved size Standard_D8s_v5

<img width="1357" height="686" alt="image" src="https://github.com/user-attachments/assets/a4ca2d91-de27-4294-bf60-9c90c2d1e9ea" />

Policy Passed with Approved VM Size

<img width="1345" height="681" alt="image" src="https://github.com/user-attachments/assets/e5656696-5e4a-4df9-a55f-549dea387751" />

VM Size Failed but Passed due to Exception

<img width="1342" height="705" alt="image" src="https://github.com/user-attachments/assets/39d7d2b0-5502-487e-9957-726bba3f1c08" />

Governance Pass (Instead of checking each Policy we can Combine together)

<img width="1331" height="678" alt="image" src="https://github.com/user-attachments/assets/8fb68cf9-c651-45f8-9364-0bd630aeb2d3" />

Governance Failed Scenario

<img width="1352" height="697" alt="image" src="https://github.com/user-attachments/assets/c54dd472-6b3b-4cce-8184-7f12e78e3c65" />

Set back to Allow changes to False made Policy Passed.

<img width="1353" height="683" alt="image" src="https://github.com/user-attachments/assets/8c6d17b8-54a0-418a-9fdb-81777075cd1c" />


non-exempted violations continue to fail the validation.

<img width="1342" height="691" alt="image" src="https://github.com/user-attachments/assets/76c67f46-aa05-45b5-a76d-8c16b179fb4c" />


---



# Application-Specific OPA Governance and Exemption Management

## 1. Overview

This project extends the existing Terraform and Open Policy Agent (OPA)
governance implementation to support application-specific policy exemptions.

The objective is to demonstrate how multiple applications can use common
infrastructure governance policies while maintaining independent exemption
configurations.

The solution consists of two components:

1. Application-specific policy validation using Terraform, OPA, and JSON.
2. Exemption request and approval automation using GitHub Issues and GitHub Actions.

The first component enforces infrastructure governance policies.

The second component simplifies how new policy exemptions are requested,
reviewed, and added to the configuration.

Both components operate together, but application-specific policy validation
can also function independently without the approval automation.

---

## 2. Requirements

The extended implementation addresses the following requirements:

- Apply common OPA governance policies to multiple applications.
- Support application-specific policy exemptions.
- Prevent exemptions from one application being used by another.
- Validate exemption details such as resource, policy, reason, ticket, and expiry.
- Reject infrastructure changes that violate policies without valid exemptions.
- Integrate application-specific OPA validation into GitHub Actions.
- Provide a configurable, code-based approach to exemption management.
- Demonstrate a GitHub-based exemption request and approval mechanism.

---

# Part 1 — Application-Specific OPA Policy Validation

The Terraform plan is generated independently for each application.

OPA evaluates the Terraform plan against the common governance policies
and the exemption configuration associated with the application.

The same OPA policies are reused across applications.

Application-specific exemption configurations determine whether a
particular policy violation is permitted.


### File Descriptions

| File | Purpose |
|------|---------|
| applications/application-a/main.tf | Terraform infrastructure for Application A |
| applications/application-b/main.tf | Terraform infrastructure for Application B |
| context.json | Identifies the application being evaluated |
| exemptions/application-a.json | Exemptions belonging to Application A |
| exemptions/application-b.json | Exemptions belonging to Application B |
| policy.rego | Validates mandatory resource tags |
| vm_size.rego | Validates approved VM sizes and applicable exemptions |
| storage_security.rego | Validates Azure Storage Account security |
| governance.rego | Combines governance policy decisions |
| terraform-opa.yml | Terraform and OPA validation workflow |
| exemption-request.yml | GitHub exemption request form |
| opa-exemption-approval.yml | GitHub exemption approval automation |

---

## 3. Common OPA Governance Policies

The project uses three infrastructure governance policies.

### Policy 1 — Mandatory Resource Tags

Ensures that applicable infrastructure resources contain the required
governance tags.

The tags include:

- environment
- project
- owner
- costcenter

A missing mandatory tag results in a policy violation unless an
applicable valid exemption exists.

### Policy 2 — Approved VM Sizes

Ensures that Linux virtual machines use approved sizes.

Approved sizes:

```rego
approved_sizes := {"Standard_B1s", "Standard_B1ms"}
```

A VM requesting another size normally violates the policy.

An application-specific exemption can permit a different VM size
for the identified resource.

### Policy 3 — Azure Storage Security

Ensures that Azure Storage Accounts do not permit public blob access
unless an applicable valid exemption exists.

The compliant Terraform configuration is:

```hcl
allow_nested_items_to_be_public = false
```

### Common Governance

The governance policy combines the individual policy results.

The overall governance decision succeeds only when the evaluated
policies have no outstanding, non-exempted violations.

---

## 4. Application Context

Each application includes a context.json file.

This identifies which application is being evaluated.

### Application A

File: applications/application-a/context.json

```json
{
  "application_context": {
    "id": "application-a"
  }
}
```

### Application B

File: applications/application-b/context.json

```json
{
  "application_context": {
    "id": "application-b"
  }
}
```

OPA uses the application identity when evaluating applicable exemptions.

An exemption belonging to Application A must not automatically
apply to Application B.

---

## 5. Application-Specific Exemptions

### Application A

Application A requires a VM size outside the standard approved list.

Example Terraform configuration:

```hcl
size = "Standard_D8s_v5"
```

The size is not included in:

```rego
approved_sizes := {"Standard_B1s", "Standard_B1ms"}
```

Therefore, it normally violates the VM-size policy.

However, Application A has an exemption in:

exemptions/application-a.json

The exemption contains the following information:

```json
{
  "application": "application-a",
  "policy": "vm_size",
  "resource": "azurerm_linux_virtual_machine.example",
  "approved_size": "Standard_D8s_v5",
  "reason": "Temporary performance testing for Application A",
  "ticket": "POC-APP-A-001",
  "expires_at": "2026-11-30T23:59:59Z"
}
```

OPA validates:

1. The application identity.
2. The policy name.
3. The Terraform resource address.
4. The requested VM size.
5. The exemption justification.
6. The ticket number.
7. The expiry date.

When the exemption is applicable and valid, the VM-size violation
is permitted.

Expected result:

```text
Application A Decision: true
```

### Application B

Application B requests the same unapproved VM size:

```hcl
size = "Standard_D8s_v5"
```

However, the Application B exemption file contains:

```json
{
  "exemptions": []
}
```

No exemption applies to Application B.

Expected result:

```text
Application B Decision: false
```

---

## 6. Cross-Application Exemption Isolation

An additional test verifies that Application B cannot use
Application A's exemption.

The test evaluates:

- Application B's Terraform plan.
- Application B's application context.
- Application A's exemption configuration.

Although Application A has an exemption for Standard_D8s_v5,
the exemption is not valid for Application B.

Expected result:

```text
Application Isolation Decision: false
```

This demonstrates that exemptions are restricted to the
application identified in the exemption configuration.

---

## 7. Local OPA Validation Commands

The following commands are executed from the repository root.

### Test 1 — Application A With Valid Exemption

```powershell
opa eval --format pretty --data policies --data applications/application-a/context.json --data exemptions/application-a.json --input applications/application-a/plan.tfplan.json "data.terraform.governance.allow"
```

Expected output:

```text
true
```

### Test 2 — Application B Without Exemption

```powershell
opa eval --format pretty --data policies --data applications/application-b/context.json --data exemptions/application-b.json --input applications/application-b/plan.tfplan.json "data.terraform.governance.allow"
```

Expected output:

```text
false
```

### Test 3 — Application B Attempting to Use Application A's Exemption

```powershell
opa eval --format pretty --data policies --data applications/application-b/context.json --data exemptions/application-a.json --input applications/application-b/plan.tfplan.json "data.terraform.governance.allow"
```

Expected output:

```text
false
```


## 8. GitHub Actions — Multi-Application Validation

The existing GitHub Actions workflow was extended to validate
Application A and Application B independently.

Workflow:

.github/workflows/terraform-opa.yml

### Expected Results

| Scenario | Expected Decision | Test Result |
|----------|-------------------|-------------|
| Application A with valid exemption | true | PASS |
| Application B without exemption | false | PASS |
| Application B using Application A's exemption | false | PASS |

GitHub Actions confirmed:

```text
Application A Decision: true
Application B Decision: false
Application Isolation Decision: false

PASSED: Application A exemption accepted.
PASSED: Application B baseline violation rejected.
PASSED: Cross-application exemption rejected.

All application-specific OPA tests PASSED.
```

In this demonstration, a false OPA decision for Application B
is an expected test result.

The GitHub Actions job succeeds because it correctly detects
the expected rejection.

<img width="1315" height="630" alt="image" src="https://github.com/user-attachments/assets/9b95303b-a3b7-4886-93d1-531182d887b6" />




# Part 2 — GitHub-Based Exemption Request and Approval Automation

## 1. Overview

The second component provides a GitHub-based mechanism for
requesting and reviewing new policy exemptions.

Without this automation, an authorized engineer can manually
update an application-specific exemption JSON file through
a reviewed code change.

The GitHub-based mechanism simplifies this process by allowing
application teams to submit structured exemption requests.

For the implemented POC, the approval automation supports
VM-size exemptions.

---

## 2. Exemption Request

The workflow does not automatically merge exemption requests.

A submitted request does not automatically provide
an active exemption.

---

## 3. GitHub Exemption Request Form

File:

.github/ISSUE_TEMPLATE/exemption-request.yml

The form collects:

- Application name
- OPA policy
- Terraform resource address
- Requested exception value
- Business justification
- Change or approval ticket
- Exemption expiry date
- Requester confirmation

### Creating a Request

Navigate to:

GitHub Repository → Issues → New Issue

Select:

OPA Policy Exemption Request

Complete the required fields and submit the issue.

### Demonstration

GitHub Issue #3 was created to request an additional
VM-size exemption for Application A.

Request details:

| Field | Value |
|-------|-------|
| Application | application-a |
| Policy | vm_size |
| Resource | azurerm_linux_virtual_machine.example |
| Requested size | Standard_D4s_v5 |
| Reason | Temporary testing requires an additional VM size |
| Ticket | POC-APP-003 |
| Expiry | 2026-11-30 |

The request was initially open and had not yet updated
the exemption configuration.

<img width="1155" height="643" alt="image" src="https://github.com/user-attachments/assets/ac567034-4417-4b43-985e-e7057d417602" />


## 4. Exemption Approval Workflow

File:

.github/workflows/opa-exemption-approval.yml

The workflow uses the GitHub issue_comment event.

The authorized approver posts:

```text
/approve-opa
```

The workflow verifies the approver identity before
processing the request.

For this POC, the configured approver is:

```text
NiteeshaNadella
```

The approval workflow performs the following operations:

1. Detects the approval comment.
2. Verifies that the comment was submitted by the configured approver.
3. Reads the GitHub issue.
4. Extracts the exemption details.
5. Validates the supported application and policy.
6. Validates the resource address and requested VM size.
7. Checks the justification, ticket, and expiry date.
8. Checks for an existing matching exemption.
9. Creates a new Git branch.
10. Generates an updated application-specific exemption JSON file.
11. Commits the proposed change.
12. Creates a pull request for review.
13. Posts the pull request reference on the GitHub issue.

The pull request must be reviewed and merged before
the new exemption configuration becomes active.


Approval workflow Success

<img width="1337" height="634" alt="image" src="https://github.com/user-attachments/assets/30a73b90-eed7-4748-8602-77977f20957d" />

---

## 5. Demonstration — Approved Exemption

The following steps were demonstrated:

### Step 1 — Submit the Request

GitHub Issue #3 requested an additional VM-size exemption
for Application A.

Requested VM size:

```text
Standard_D4s_v5
```

### Step 2 — Approve the Request

The authorized approver commented:

```text
/approve-opa
```

### Step 3 — Execute Approval Automation

GitHub Actions executed the OPA Exemption Approval workflow.

The workflow validated the request and generated
a proposed exemption configuration change.

### Step 4 — Create Pull Request

The automation created:

Pull Request #4

Title:

```text
OPA exemption: application-a - vm_size
```

### Step 5 — Review the JSON Changes

The pull request added a new exemption:

```json
{
  "application": "application-a",
  "policy": "vm_size",
  "resource": "azurerm_linux_virtual_machine.example",
  "approved_size": "Standard_D4s_v5",
  "reason": "Temporary testing requires an additional VM size.",
  "ticket": "POC-APP-003",
  "expires_at": "2026-11-30T23:59:59Z"
}
```

The existing Standard_D8s_v5 exemption was preserved.

### Step 6 — Merge Pull Request

Pull Request #4 was reviewed and merged into main.

### Step 7 — Run Terraform OPA Validation

The merge triggered the Terraform OPA Policy Validation workflow.

The workflow completed successfully.

This demonstrated that the updated exemption configuration
did not break the existing governance validation.

A separate Terraform plan evaluation using Standard_D4s_v5
would be required to independently demonstrate that the
newly added exemption permits that VM size.

#### 1. GitHub Exemption Request — Issue #3

Application A submitted an exemption request through GitHub Issues
to use an additional VM size, Standard_D4s_v5.

The request includes the application name, policy, Terraform resource,
requested VM size, business justification, ticket number, and expiry date.


<img width="1327" height="645" alt="image" src="https://github.com/user-attachments/assets/9d1e5d13-df91-4e34-bd01-14aae6c07c16" />


<img width="1245" height="638" alt="image" src="https://github.com/user-attachments/assets/d9b848a1-4fe2-40b2-857f-2c28827fb69e" />


Generate Exemptions

<img width="1337" height="626" alt="image" src="https://github.com/user-attachments/assets/e0862883-f89b-43ce-9b64-cf400b0f63f6" />


Pull request Merged and closed

<img width="1265" height="634" alt="image" src="https://github.com/user-attachments/assets/4f36d812-6044-4181-ad6d-680b60283fa5" />


Governance After Merge

<img width="1339" height="627" alt="image" src="https://github.com/user-attachments/assets/be9fef4c-58cb-4d95-8ab7-fdb891178dda" />


## 6. Security and Governance Considerations

The implementation demonstrates several governance controls:

### Application Isolation

An exemption is matched against the application identity.

An exemption belonging to Application A cannot be
reused by Application B.

### Policy-Specific Exemptions

An exemption identifies the relevant OPA policy.

An exemption for VM-size validation does not automatically
exempt other infrastructure policies.

### Resource-Specific Exemptions

The exemption references a specific Terraform resource address.

### Expiry Validation

The expiry date is evaluated to determine whether
the exemption remains valid.


---

## 7. Conclusion

This proof of concept demonstrates the integration of
Terraform, Open Policy Agent, Rego, JSON-based policy exemptions,
and GitHub Actions.

The implementation enforces common governance policies
across multiple applications while allowing approved,
application-specific policy exceptions.

Application A successfully passed governance validation
using its valid VM-size exemption.

Application B failed governance validation when requesting
the same unapproved VM size without an exemption.

Cross-application testing confirmed that Application B
could not reuse Application A's exemption.

An additional GitHub-based exemption management process
was implemented to demonstrate structured exemption requests,
authorized processing, automated pull request creation,
review, and integration with the existing governance workflow.

The solution provides a configurable, code-based approach to
policy enforcement and exemption management without requiring
a dedicated web portal.

---








