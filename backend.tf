terraform {
  backend "s3" {
    profile        = "storetheindex"
    bucket         = "load-testing-tfstate"
    key            = "indexer-state"
    region         = "us-west-2"
    dynamodb_table = "terraform-locking"
    encrypt        = true
  }
}
