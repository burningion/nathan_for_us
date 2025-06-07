defmodule NathanForUs.SocialFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `NathanForUs.Social` context.
  """

  alias NathanForUs.AccountsFixtures

  def valid_post_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      content: "This is a revolutionary business strategy that will disrupt the industry",
      image_url: nil
    })
  end

  def post_fixture(attrs \\ %{}) do
    user = attrs[:user] || AccountsFixtures.user_fixture()
    
    attrs = 
      attrs
      |> Map.put(:user_id, user.id)
      |> valid_post_attributes()

    {:ok, post} = NathanForUs.Social.create_post(attrs)
    NathanForUs.Repo.preload(post, :user)
  end

  def valid_follow_attributes(attrs \\ %{}) do
    follower = attrs[:follower] || AccountsFixtures.user_fixture()
    following = attrs[:following] || AccountsFixtures.user_fixture()

    Enum.into(attrs, %{
      follower_id: follower.id,
      following_id: following.id
    })
  end

  def follow_fixture(attrs \\ %{}) do
    attrs = valid_follow_attributes(attrs)
    {:ok, follow} = NathanForUs.Social.follow_user(attrs.follower_id, attrs.following_id)
    follow
  end

  def create_follow_relationship(follower_user, following_user) do
    {:ok, _follow} = NathanForUs.Social.follow_user(follower_user.id, following_user.id)
  end
end