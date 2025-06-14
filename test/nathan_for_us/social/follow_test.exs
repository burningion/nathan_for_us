defmodule NathanForUs.Social.FollowTest do
  use NathanForUs.DataCase

  alias NathanForUs.Social.Follow

  import NathanForUs.AccountsFixtures

  describe "changeset/2" do
    setup do
      follower = user_fixture()
      following = user_fixture()
      %{follower: follower, following: following}
    end

    test "valid changeset with follower_id and following_id", %{
      follower: follower,
      following: following
    } do
      attrs = %{follower_id: follower.id, following_id: following.id}
      changeset = Follow.changeset(%Follow{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without follower_id", %{following: following} do
      attrs = %{following_id: following.id}
      changeset = Follow.changeset(%Follow{}, attrs)
      refute changeset.valid?
      assert %{follower_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without following_id", %{follower: follower} do
      attrs = %{follower_id: follower.id}
      changeset = Follow.changeset(%Follow{}, attrs)
      refute changeset.valid?
      assert %{following_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset with same follower_id and following_id", %{follower: follower} do
      attrs = %{follower_id: follower.id, following_id: follower.id}
      changeset = Follow.changeset(%Follow{}, attrs)
      refute changeset.valid?
      assert %{following_id: ["cannot follow yourself"]} = errors_on(changeset)
    end

    test "invalid changeset with nil values" do
      attrs = %{follower_id: nil, following_id: nil}
      changeset = Follow.changeset(%Follow{}, attrs)
      refute changeset.valid?
      assert %{follower_id: ["can't be blank"]} = errors_on(changeset)
      assert %{following_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "associations" do
    test "follow belongs to follower and following users" do
      follower = user_fixture()
      following = user_fixture()

      {:ok, follow} =
        %Follow{}
        |> Follow.changeset(%{follower_id: follower.id, following_id: following.id})
        |> Repo.insert()

      follow_with_users = Repo.preload(follow, [:follower, :following])
      assert follow_with_users.follower.id == follower.id
      assert follow_with_users.following.id == following.id
    end
  end

  describe "database constraints" do
    setup do
      follower = user_fixture()
      following = user_fixture()
      %{follower: follower, following: following}
    end

    test "unique constraint prevents duplicate follows", %{
      follower: follower,
      following: following
    } do
      attrs = %{follower_id: follower.id, following_id: following.id}

      # First follow should succeed
      {:ok, _follow1} =
        %Follow{}
        |> Follow.changeset(attrs)
        |> Repo.insert()

      # Second follow with same users should fail
      changeset = Follow.changeset(%Follow{}, attrs)
      assert changeset.valid?

      assert {:error, changeset} = Repo.insert(changeset)
      assert %{follower_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "follower_id foreign key constraint", %{following: following} do
      invalid_follower_id = 999_999
      attrs = %{follower_id: invalid_follower_id, following_id: following.id}

      changeset = Follow.changeset(%Follow{}, attrs)
      assert changeset.valid?

      assert {:error, changeset} = Repo.insert(changeset)
      assert %{follower_id: ["does not exist"]} = errors_on(changeset)
    end

    test "following_id foreign key constraint", %{follower: follower} do
      invalid_following_id = 999_999
      attrs = %{follower_id: follower.id, following_id: invalid_following_id}

      changeset = Follow.changeset(%Follow{}, attrs)
      assert changeset.valid?

      assert {:error, changeset} = Repo.insert(changeset)
      assert %{following_id: ["does not exist"]} = errors_on(changeset)
    end

    test "follow can be created and deleted", %{follower: follower, following: following} do
      {:ok, follow} =
        %Follow{}
        |> Follow.changeset(%{follower_id: follower.id, following_id: following.id})
        |> Repo.insert()

      assert Repo.get(Follow, follow.id)

      {:ok, _deleted_follow} = Repo.delete(follow)
      refute Repo.get(Follow, follow.id)
    end

    test "deleting user cascades to delete follows", %{follower: follower, following: following} do
      {:ok, follow} =
        %Follow{}
        |> Follow.changeset(%{follower_id: follower.id, following_id: following.id})
        |> Repo.insert()

      assert Repo.get(Follow, follow.id)

      # Delete the follower user
      Repo.delete(follower)

      # Follow should be automatically deleted due to cascade
      refute Repo.get(Follow, follow.id)
    end

    test "user can follow multiple users", %{follower: follower} do
      following1 = user_fixture()
      following2 = user_fixture()

      {:ok, follow1} =
        %Follow{}
        |> Follow.changeset(%{follower_id: follower.id, following_id: following1.id})
        |> Repo.insert()

      {:ok, follow2} =
        %Follow{}
        |> Follow.changeset(%{follower_id: follower.id, following_id: following2.id})
        |> Repo.insert()

      assert Repo.get(Follow, follow1.id)
      assert Repo.get(Follow, follow2.id)
    end

    test "user can be followed by multiple users", %{following: following} do
      follower1 = user_fixture()
      follower2 = user_fixture()

      {:ok, follow1} =
        %Follow{}
        |> Follow.changeset(%{follower_id: follower1.id, following_id: following.id})
        |> Repo.insert()

      {:ok, follow2} =
        %Follow{}
        |> Follow.changeset(%{follower_id: follower2.id, following_id: following.id})
        |> Repo.insert()

      assert Repo.get(Follow, follow1.id)
      assert Repo.get(Follow, follow2.id)
    end
  end
end
