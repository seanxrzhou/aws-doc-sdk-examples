# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX - License - Identifier: Apache - 2.0

# This code example allows a federated user with a limited set of
# permissions to list the objects in the specified Amazon S3 bucket.

# snippet-start:[s3.ruby.auth_federation_token_request_test.rb]
require 'aws-sdk-s3'
require 'aws-sdk-iam'
require 'json'

# Checks to see whether the specified user exists in AWS IAM; otherwise,
# creates the user.
#
# @param iam [Aws::IAM::Client] An initialized AWS IAM client.
# @param user_name [String] The user's name.
# @return [Aws::IAM::Types::User] The existing or new user.
# @example
#   iam = Aws::IAM::Client.new(region: 'us-east-1')
#   user = get_user(iam, 'my-user')
#   puts "User's name is #{user.user_name}"
def get_user(iam, user_name)
  puts "Checking for a user with the name '#{user_name}'..."
  response = iam.get_user(user_name: user_name)
  puts "A user with the name '#{user_name}' already exists."
  return response.user
# If the user doesn't exit, create them.
rescue Aws::IAM::Errors::NoSuchEntity
  puts "A user with the name '#{user_name}' doesn't exist. Creating this user..."
  response = iam.create_user(user_name: user_name)
  iam.wait_until(:user_exists, user_name: user_name)
  puts "Created user with the name '#{user_name}'."
  return response.user
rescue StandardError => e
  puts "Error while accessing or creating the user named '#{user_name}': #{e.message}"
end

# Gets temporary AWS credentials for the specified AWS IAM user and permissions.
#
# @param sts [Aws::STS::Client] An initialized AWS STS client.
# @param duration_seconds [Integer] The number of seconds for valid credentials.
# @param user_name [String] The user's name.
# @param policy [Hash] The permissions' access policy.
# @return [Aws::STS::Types::Credentials] AWS credentials for API authentication.
# @example
#   sts = Aws::STS::Client.new(region: 'us-east-1')
#   credentials = get_temporary_credentials(sts, duration_seconds, user_name, 
#     {
#       'Version' => '2012-10-17',
#       'Statement' => [
#         'Sid' => 'Stmt1',
#         'Effect' => 'Allow',
#         'Action' => 's3:ListBucket',
#         'Resource' => 'arn:aws:s3:::my-bucket'
#       ]
#     }
#   )
#   puts "Access key ID is #{credentials.access_key_id}"
def get_temporary_credentials(sts, duration_seconds, user_name, policy)
  response = sts.get_federation_token(
    duration_seconds: duration_seconds,
    name: user_name,
    policy: policy.to_json
  )
  return response.credentials
rescue StandardError => e
  puts "Error while getting federation token: #{e.message}"
end

# Lists the keys and ETags for the objects in the specified Amazon S3 bucket.
#
# @param s3 [Aws::S3::Client] An initialized Amazon S3 client.
# @param bucket_name [String] The bucket's name.
# @return [Boolean] true if the objects were listed; otherwise, false.
# @example
#   s3 = Aws::S3::Client.new(region: 'us-east-1')
#   unless can_list_objects_in_bucket?(s3, 'my-bucket')
#     exit 1
#   end
def can_list_objects_in_bucket?(s3, bucket_name)
  puts "Accessing the contents of the bucket named '#{bucket_name}'..."
  response = s3.list_objects_v2(
    bucket: bucket_name,
    max_keys: 50
  )

  if response.count.positive?
    puts "Contents of the bucket named '#{bucket_name}' (first 50 objects):"
    puts 'Name => ETag'
    response.contents.each do |obj|
      puts "#{obj.key} => #{obj.etag}"
    end
  else
    puts "No objects in the bucket named '#{bucket_name}'."
  end
  return true
rescue StandardError => e
  puts "Error while accessing the bucket named '#{bucket_name}': #{e.message}"
  return false
end
# snippet-end:[s3.ruby.auth_federation_token_request_test.rb]

# Full example:
=begin
region = 'us-east-1'
user_name = 'my-user'
bucket_name = 'my-bucket'

iam = Aws::IAM::Client.new(region: region)
user = get_user(iam, user_name)

unless user.user_name
  exit 1
end

puts "User's name: #{user.user_name}"
sts = Aws::STS::Client.new(region: region)

credentials = get_temporary_credentials(sts, 3600, user_name,
  {
    'Version' => '2012-10-17',
    'Statement' => [
      'Sid' => 'Stmt1',
      'Effect' => 'Allow',
      'Action' => 's3:ListBucket',
      'Resource' => "arn:aws:s3:::#{bucket_name}"
    ]
  }
)

unless credentials
  exit 1
end

puts "Access key ID: #{credentials.access_key_id}"
s3 = Aws::S3::Client.new(region: region, credentials: credentials)

unless can_list_objects_in_bucket?(s3, bucket_name)
  exit 1
end
=end
