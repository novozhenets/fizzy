require "test_helper"

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "edit" do
    get edit_bucket_url(buckets(:writebook))
    assert_response :success
  end

  test "update" do
    patch bucket_url(buckets(:writebook)), params: { bucket: { name: "Writebook bugs" }, user_ids: users(:david, :jz).pluck(:id) }
    assert_redirected_to bucket_bubbles_url(buckets(:writebook))
    assert_equal users(:david, :jz), buckets(:writebook).users
    assert_equal "Writebook bugs", buckets(:writebook).reload.name
  end
end
