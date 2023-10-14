terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.21.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

locals {
  carriageReturn = "\r"
  additionalTags = {
    "Domain"      = "DEV"
    "Application" = "InfraPipe"
  }
  thisPolicyId = "iam-policy-test"
  svcRoleTrustPolicy = {
    "AllowAssumeRole" = {
      Effect  = "Allow"
      Actions = ["sts:AssumeRole"]
      Principals = {
        "SvcAccount" = {
          Type = "AWS"
          Identifiers = [
            module.infraUser.userARN
          ]
        }
      }
    }
  }
  svcGroupPermissionPolicy = {
    "AllowAllCloudFormationAccessToSpecificResources" = {
      Effect = "Allow"
      Actions = [
        "cloudformation:*"
      ],
      Resources = [
        "arn:aws:cloudformation:*:581698278165:type/resource/*",
        "arn:aws:cloudformation:*:581698278165:stackset/*:*",
        "arn:aws:cloudformation:*:581698278165:stackset-target/*",
        "arn:aws:cloudformation:*:581698278165:stack/*/*",
        "arn:aws:cloudformation:*:581698278165:changeSet/*/*"
      ]
    },
    "AllowSpecificCloudFormationAccessToAllResources" = {
      Effect = "Allow"
      Actions = [
        "cloudformation:TestType",
        "cloudformation:SetTypeDefaultVersion",
        "cloudformation:SetTypeConfiguration",
        "cloudformation:RegisterType",
        "cloudformation:RegisterPublisher",
        "cloudformation:PublishType",
        "cloudformation:ListTypes",
        "cloudformation:ListTypeVersions",
        "cloudformation:ListTypeRegistrations",
        "cloudformation:ListStacks",
        "cloudformation:ListStackSets",
        "cloudformation:ListImports",
        "cloudformation:ListExports",
        "cloudformation:EstimateTemplateCost",
        "cloudformation:DescribeTypeRegistration",
        "cloudformation:DescribeType",
        "cloudformation:DescribeStackDriftDetectionStatus",
        "cloudformation:DescribePublisher",
        "cloudformation:DescribeOrganizationsAccess",
        "cloudformation:DescribeAccountLimits",
        "cloudformation:DeregisterType",
        "cloudformation:DeactivateType",
        "cloudformation:DeactivateOrganizationsAccess",
        "cloudformation:CreateUploadBucket",
        "cloudformation:CreateStackSet",
        "cloudformation:BatchDescribeTypeConfigurations",
        "cloudformation:ActivateType",
        "cloudformation:ActivateOrganizationsAccess"

      ],
      Resources = [
        "*"
      ]
    }
  }
}

module "groupPermissionPolicyDocument" {
  source          = "app.terraform.io/ag6hq/policy-document/aws"
  version         = "0.1.1"
  policyId        = "permission-policy"
  policyStatement = local.svcGroupPermissionPolicy
}

module "groupPermissionPolicy" {
  source            = "app.terraform.io/ag6hq/policy/aws"
  version           = "0.1.0"
  policyName        = "svcpcy-ag6hq-infrapipe"
  policyDescription = "Infrapipe Policies"
  policyDocument    = module.groupPermissionPolicyDocument.policyDocument
}

module "infraGroup" {
  source    = "app.terraform.io/ag6hq/user-group/aws"
  version   = "0.1.0"
  groupName = "svcgrp-ag6hq-infrapipe"
  groupPath = "/"
}

resource "aws_iam_group_policy_attachment" "infrapipe" {
  group      = module.infraGroup.userGroup.name
  policy_arn = module.groupPermissionPolicy.policyARN
}

module "infraUser" {
  source  = "app.terraform.io/ag6hq/user/aws"
  version = "0.1.0"

  userName = "svcacnt-ag6hq-infrapipe"

  theseTags = merge(local.additionalTags, ({
  "Access_Key" = "AKIAYO37LKMK2ONWZ4PZ" }))
}

resource "aws_iam_user_group_membership" "infrapipe" {

  user = module.infraUser.userName

  groups = [
    module.infraGroup.userGroup.name
  ]

}

module "roleTrustPolicyDocument" {
  source          = "app.terraform.io/ag6hq/policy-document/aws"
  version         = "0.1.1"
  policyId        = "role-trust-policy"
  policyStatement = local.svcRoleTrustPolicy
}

resource "aws_iam_role" "infrapipe" {
  name               = "svcrole-ag6hq-infrapipe"
  path               = "/"
  description        = "Service Role for Infrapipe"
  assume_role_policy = module.roleTrustPolicyDocument.policyDocument
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
  ]
  tags = merge(
    local.additionalTags,
    tomap(
      {
        "name" = "svcrole-ag6hq-infrapipe"
      }
    )
  )

}

resource "aws_iam_access_key" "svcacnt" {
  user = module.infraUser.userName
}

resource "local_file" "svcacntKeys" {
  content         = <<SVCACNTKEYS
Access key ID,Secret access key
${aws_iam_access_key.svcacnt.id},${aws_iam_access_key.svcacnt.secret}
SVCACNTKEYS
  filename        = pathexpand("~/.ssh/${module.infraUser.userName}_accessKeys.csv")
  file_permission = "0644"
}

output "userName" {
  value = module.infraUser.userName
}

output "groupPolicy" {
  value = module.groupPermissionPolicy.policyName
}

output "groupName" {
  value = module.infraGroup.userGroup.name
}

output "roleName" {
  value = aws_iam_role.infrapipe.name
}

output "svcacntAccessKey" {
  value = aws_iam_access_key.svcacnt.id
}

output "svcacntSecretKey" {
  sensitive = true
  value     = aws_iam_access_key.svcacnt.secret
}

output "svcacntKeysFile" {
  value = local_file.svcacntKeys.filename
}