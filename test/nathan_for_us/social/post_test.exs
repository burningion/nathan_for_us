defmodule NathanForUs.Social.PostTest do
  use NathanForUs.DataCase

  alias NathanForUs.Social.Post

  import NathanForUs.AccountsFixtures

  describe "changeset/2" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "valid changeset with content only", %{user: user} do
      attrs = %{content: "Revolutionary business strategy", user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with image_url only", %{user: user} do
      attrs = %{image_url: "/uploads/chart.png", user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with both content and image_url", %{user: user} do
      attrs = %{
        content: "Check out this chart",
        image_url: "/uploads/chart.png",
        user_id: user.id
      }

      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without user_id" do
      attrs = %{content: "Some content"}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without content or image_url", %{user: user} do
      attrs = %{user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content: ["must have either content or image"]} = errors_on(changeset)
    end

    test "invalid changeset with nil content and nil image_url", %{user: user} do
      attrs = %{content: nil, image_url: nil, user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content: ["must have either content or image"]} = errors_on(changeset)
    end

    test "invalid changeset with empty string content and nil image_url", %{user: user} do
      attrs = %{content: "", image_url: nil, user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      refute changeset.valid?
      assert %{content: ["must have either content or image"]} = errors_on(changeset)
    end

    test "valid changeset with empty string content but valid image_url", %{user: user} do
      attrs = %{content: "", image_url: "/uploads/chart.png", user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "changeset trims content field", %{user: user} do
      attrs = %{content: "  Trimmed content  ", user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :content) == "Trimmed content"
    end

    test "changeset allows long content", %{user: user} do
      long_content = String.duplicate("a", 5000)
      attrs = %{content: long_content, user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
    end

    test "changeset validates foreign key constraint for user_id", %{user: user} do
      attrs = %{content: "Some content", user_id: user.id}
      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?
      assert changeset.changes.user_id == user.id
    end
  end

  describe "associations" do
    test "post belongs to user" do
      user = user_fixture()

      {:ok, post} =
        %Post{}
        |> Post.changeset(%{content: "Test post", user_id: user.id})
        |> Repo.insert()

      post_with_user = Repo.preload(post, :user)
      assert post_with_user.user.id == user.id
      assert post_with_user.user.email == user.email
    end
  end

  describe "database constraints" do
    test "user_id foreign key constraint" do
      invalid_user_id = 999_999
      attrs = %{content: "Test content", user_id: invalid_user_id}

      changeset = Post.changeset(%Post{}, attrs)
      assert changeset.valid?

      assert {:error, changeset} = Repo.insert(changeset)
      assert %{user_id: ["does not exist"]} = errors_on(changeset)
    end

    test "post can be created and deleted" do
      user = user_fixture()

      {:ok, post} =
        %Post{}
        |> Post.changeset(%{content: "Test post", user_id: user.id})
        |> Repo.insert()

      assert Repo.get(Post, post.id)

      {:ok, _deleted_post} = Repo.delete(post)
      refute Repo.get(Post, post.id)
    end
  end
end
