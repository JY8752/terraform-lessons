#GitHubプロバイダの定義
provider "github" {
  organization = "my-github-name"
}

module "ecs" {
  source = "../ecs"
}

#ECRリポジトリの定義
resource "aws_ecr_repository" "example" {
  name = "example"
}

#ECRライフサイクルポリシーの定義
#releaseで始まるイメージタグを30個までに制限
resource "aws_ecr_lifecycle_policy" "example" {
  repository = aws_ecr_repository.example.name
  policy     = <<EOF
  {
	  "rules": [
		  {
			  "rulePriority": 1,
			  "description": "Keep last release tagged images",
			  "selection": {
				  "tagStatus": "tagged",
				  "tagPrefixList": ["release"],
				  "countType": "imageCountMoreThan",
				  "countNumber": 30
			  },
			  "action": {
				  "type": "expire"
			  }
		  }
	  ]
  }
  EOF
}

#CodeBuildサービスロールのポリシードキュメント
data "aws_iam_policy_document" "codebuild" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      #ビルド成果物を保存するためのs3操作権限
      "s3:PutObject",
      "s3:GetObject",
      "s3:ObjectVersion",
      #ビルドログを出力するためのCloudWatchLogs操作権限
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      #DockerイメージをプッシュするためのRCR操作権限
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribesRepositories",
      "ecr:ListImages",
      "ecr:DescribesImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
  }
}

#CodeBuildサービスロールの定義
module "codebuild_role" {
  source     = "../iam_role"
  name       = "codebuild"
  identifier = "codebuild.amazonaws.com"
  policy     = data.aws_iam_policy_document.codebuild.json
}

#CodeBuildプロジェクトの作成
resource "aws_codebuild_project" "example" {
  name         = "example"
  service_role = module.codebuild_role.iam_role_arn
  #ビルド対象のファイル
  source {
    type = "CODEPIPELINE"
  }
  #ビルド出力の格納先
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:2.0"
    privileged_mode = true
  }
}

#CodePipelineサービスロールのポリシードキュメントの定義
data "aws_iam_policy_document" "codepipeline" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      #ステージ間でデータを受け渡すための操作権限
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      #CodeBuildを起動するための権限
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      #DockerイメージをデプロイするためのECS操作権限
      "ecs:DescribeServices",
      "ecs:DescribeTAskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      #CodeBuildやECSにロールを渡すためのPassRole権限
      "iam:PassRole"
    ]
  }
}

#CodePipelineサービスロールの定義
module "codepipeline_role" {
  source     = "../iam_role"
  name       = "codepipeline"
  identifier = "codepipeline.amazonaws.com"
  policy     = data.aws_iam_policy_document.codepipeline.json
}

#アーティファクトストアの定義
resource "aws_s3_bucket" "artifact" {
  bucket = "artifact-pragmatic-terraform"
}

resource "aws_s3_bucket_lifecycle_configuration" "example" {
  bucket = aws_s3_bucket.artifact.id
  rule {
    id     = "config"
    status = "Enabled"
    expiration {
      days = "180"
    }
  }
}

#CodePipelineの定義
resource "aws_codepipeline" "example" {
  name     = "example"
  role_arn = module.codepipeline_role.iam_role_arn
  #sourceステージ
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = 1
      output_artifacts = ["Source"]
      configuration = {
        Owner                = "JY8752"
        Repo                 = "my-repository"
        Branch               = "main"
        PollForSourceChanges = false #Webhookから行うためポーリングは無効
      }
    }
  }
  #buildステージ
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = 1
      input_artifacts  = ["Source"]
      output_artifacts = ["Build"]
      configuration = {
        ProjectName = aws_codebuild_project.example.id
      }
    }
  }
  #deployステージ
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = 1
      input_artifacts = ["Build"]
      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs.service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
  artifact_store {
    location = aws_s3_bucket.artifact.id
    type     = "s3"
  }
}

#CodePipeline Webhookの定義
resource "aws_codepipeline_webhook" "example" {
  name            = "example"
  target_pipeline = aws_codepipeline.example.name
  target_action   = "Source" #最初に実行するアクション
  authentication  = "GITHUB_HMAC"
  authentication_configuration {
    secret_token = "VeryRandomStringMoreThan20Byte!" #tfstateファイルに平文で書き込まれる
  }
  #mainブランチのときのみに限定
  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}

#GitHub Webhookの定義
resource "github_repository_webhook" "example" {
  repository = "my-repository"
  configuration {
    url          = aws_codepipeline_webhook.example.url
    secret       = "VeryRandomStringMoreThan20Byte!" #CodePipeline Webhookのsecret_tokenと同じ値
    content_type = "json"
    insecure_ssl = false
  }
  events = ["push"] #pull_requestなども指定できる
}
