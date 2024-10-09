require "test_helper"

class Bubbles::PopsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    bubble = bubbles(:logo)

    assert_changes -> { bubble.reload.popped? }, from: false, to: true do
      post bucket_bubble_pop_url(bubble.bucket, bubble)
    end

    assert_redirected_to bucket_bubble_url(bubble.bucket, bubble)
  end

  test "destroy" do
    bubble = bubbles(:shipping)

    assert_changes -> { bubble.reload.popped? }, from: true, to: false do
      delete bucket_bubble_pop_url(bubble.bucket, bubble)
    end

    assert_redirected_to bucket_bubble_url(bubble.bucket, bubble)
  end
end
