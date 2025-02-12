class Users::AvatarsController < ApplicationController
  include ActiveStorage::Streaming

  before_action :set_user

  def show
    fresh_when @user, cache_control: { max_age: 30.minutes, stale_while_revalidate: 1.week }

    if @user.avatar.attached?
      send_blob_stream @user.avatar
    else
      render_initials
    end
  end

  def destroy
    @user.avatar.destroy
    redirect_to user_path(@user)
  end

  private
    def set_user
      @user = Current.account.users.find(params[:user_id])
    end

    def render_initials
      render formats: :svg
    end
end
