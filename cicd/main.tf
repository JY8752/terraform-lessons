#AMIロールの作成
module "continuous_apply_codebuild_role" {
  source     = "./module/iam"
  name       = "continuous-apply"
  identifier = "codebuild.amazonaws.com"
  policy     = data.aws_iam_policy.administrator_access.policy
}

data "aws_iam_policy" "administrator_access" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

#codebuild
resource "aws_codebuild_project" "continuous_apply" {
  name         = "continuous-apply"
  service_role = module.continuous_apply_codebuild_role.iam_role_arn
  source {
    type     = "GITHUB"
    location = "https://github.com/JY8752/......"
  }
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "hashicorp/terraform:1.1.7"
    privileged_mode = false
  }
  provisioner "local-exec" {
    command = <<-EOT
        aws codebuild import-source-credentials \
        --server-type GITHUB \
        --auth-type PERSONAL_ACCESS_TOKEN \
        --token $GITHUB_TOKEN
    EOT
    environment = {
      GITHUB_TOKEN = data.aws_ssm_parameter.github_token.value
    }
  }
}

#パラメーターストアからgithub_token取得
data "aws_ssm_parameter" "github_token" {
  name = "/continuous_apply/github_token"
}

#CodeBuild Webhookの定義
resource "aws_codebuild_webhook" "continuous_apply" {
  project_name = aws_codebuild_project.continuous_apply.name
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED"
    }
  }
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_UPDATED"
    }
  }
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "master"
    }
  }
}
