defmodule NathanForUs.AccountsExtendedTest do
  use NathanForUs.DataCase
  
  alias NathanForUs.Accounts
  alias NathanForUs.Accounts.{User, UserToken}
  
  import NathanForUs.AccountsFixtures, except: [valid_user_attributes: 0, extract_user_token: 1]
  
  describe "registration" do
    test "register_user/1 with valid data creates user" do
      valid_attrs = valid_user_attributes()
      
      assert {:ok, %User{} = user} = Accounts.register_user(valid_attrs)
      assert user.email == valid_attrs.email
      assert is_binary(user.hashed_password)
      assert user.hashed_password != valid_attrs.password
      assert is_nil(user.confirmed_at)
    end
    
    test "register_user/1 with invalid email returns changeset error" do
      invalid_attrs = %{email: "invalid", password: "validpassword123"}
      
      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end
    
    test "register_user/1 with short password returns changeset error" do
      invalid_attrs = %{email: "test@example.com", password: "short"}
      
      assert {:error, changeset} = Accounts.register_user(invalid_attrs)
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end
    
    test "register_user/1 with duplicate email returns changeset error" do
      %{email: email} = user_fixture()
      duplicate_attrs = %{email: email, password: "validpassword123"}
      
      assert {:error, changeset} = Accounts.register_user(duplicate_attrs)
      assert "has already been taken" in errors_on(changeset).email
    end
    
    test "change_user_registration/2 returns valid changeset" do
      user = %User{}
      attrs = valid_user_attributes()
      
      changeset = Accounts.change_user_registration(user, attrs)
      
      assert changeset.valid?
      assert get_change(changeset, :email) == attrs.email
    end
  end
  
  describe "authentication" do
    test "get_user_by_email/1 returns user with valid email" do
      %{email: email} = user = user_fixture()
      assert Accounts.get_user_by_email(email).id == user.id
    end
    
    test "get_user_by_email/1 returns nil with invalid email" do
      assert is_nil(Accounts.get_user_by_email("nonexistent@example.com"))
    end
    
    test "get_user_by_email_and_password/2 returns user with correct credentials" do
      password = "hello world!"
      %{email: email} = user = user_fixture(%{password: password})
      
      assert Accounts.get_user_by_email_and_password(email, password).id == user.id
    end
    
    test "get_user_by_email_and_password/2 returns nil with incorrect password" do
      %{email: email} = user_fixture(%{password: "hello world!"})
      
      assert is_nil(Accounts.get_user_by_email_and_password(email, "wrongpassword"))
    end
    
    test "get_user_by_email_and_password/2 returns nil with invalid email" do
      assert is_nil(Accounts.get_user_by_email_and_password("nonexistent@example.com", "anypassword"))
    end
  end
  
  describe "email updates" do
    test "apply_user_email/3 with valid password and email succeeds" do
      password = "hello world!"
      user = user_fixture(%{password: password})
      new_email = "new@example.com"
      
      assert {:ok, applied_user} = Accounts.apply_user_email(user, password, %{email: new_email})
      assert applied_user.email == new_email
    end
    
    test "apply_user_email/3 with invalid password fails" do
      user = user_fixture(%{password: "hello world!"})
      
      assert {:error, changeset} = Accounts.apply_user_email(user, "wrongpassword", %{email: "new@example.com"})
      assert "is not valid" in errors_on(changeset).current_password
    end
    
    test "apply_user_email/3 with invalid email fails" do
      password = "hello world!"
      user = user_fixture(%{password: password})
      
      assert {:error, changeset} = Accounts.apply_user_email(user, password, %{email: "invalid"})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end
    
    test "update_user_email/2 with valid token updates email" do
      user = user_fixture()
      new_email = "new@example.com"
      token = extract_user_token(fn url -> 
        Accounts.deliver_user_update_email_instructions(user, user.email, url)
      end)
      
      # Update the token's sent_to field to the new email
      context = "change:#{user.email}"
      token_record = Repo.get_by!(UserToken, [context: context, user_id: user.id])
      Repo.update!(Ecto.Changeset.change(token_record, %{sent_to: new_email}))
      
      assert :ok = Accounts.update_user_email(user, token)
      
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.email == new_email
      assert updated_user.confirmed_at
    end
    
    test "update_user_email/2 with invalid token returns error" do
      user = user_fixture()
      assert :error = Accounts.update_user_email(user, "invalid_token")
    end
    
    test "change_user_email/2 returns valid changeset" do
      user = user_fixture()
      changeset = Accounts.change_user_email(user, %{email: "new@example.com"})
      
      assert changeset.valid?
      assert get_change(changeset, :email) == "new@example.com"
    end
  end
  
  describe "password updates" do
    test "update_user_password/3 with valid password updates successfully" do
      password = "hello world!"
      user = user_fixture(%{password: password})
      new_password = "new valid password"
      
      assert {:ok, updated_user} = Accounts.update_user_password(user, password, %{
        password: new_password,
        password_confirmation: new_password
      })
      
      assert is_binary(updated_user.hashed_password)
      assert updated_user.hashed_password != user.hashed_password
      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end
    
    test "update_user_password/3 with invalid current password fails" do
      user = user_fixture(%{password: "hello world!"})
      
      assert {:error, changeset} = Accounts.update_user_password(user, "wrongpassword", %{
        password: "new valid password",
        password_confirmation: "new valid password"
      })
      
      assert "is not valid" in errors_on(changeset).current_password
      assert Accounts.get_user_by_email_and_password(user.email, "hello world!")
    end
    
    test "update_user_password/3 with invalid new password fails" do
      password = "hello world!"
      user = user_fixture(%{password: password})
      
      assert {:error, changeset} = Accounts.update_user_password(user, password, %{
        password: "short",
        password_confirmation: "short"
      })
      
      assert "should be at least 12 character(s)" in errors_on(changeset).password
      assert Accounts.get_user_by_email_and_password(user.email, password)
    end
    
    test "update_user_password/3 revokes all user tokens" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      
      assert Accounts.get_user_by_session_token(token)
      
      assert {:ok, _} = Accounts.update_user_password(user, "hello world!", %{
        password: "new valid password",
        password_confirmation: "new valid password"
      })
      
      refute Accounts.get_user_by_session_token(token)
    end
    
    test "change_user_password/2 returns valid changeset" do
      user = user_fixture()
      changeset = Accounts.change_user_password(user)
      
      assert %Ecto.Changeset{} = changeset
      assert changeset.valid?
    end
  end
  
  describe "session management" do
    test "generate_user_session_token/1 creates valid token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      
      assert is_binary(token)
      assert byte_size(token) > 10
    end
    
    test "get_user_by_session_token/1 returns user for valid token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end
    
    test "get_user_by_session_token/1 returns nil for invalid token" do
      assert is_nil(Accounts.get_user_by_session_token("invalid_token"))
    end
    
    test "delete_user_session_token/1 removes token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      
      assert Accounts.get_user_by_session_token(token)
      assert :ok = Accounts.delete_user_session_token(token)
      refute Accounts.get_user_by_session_token(token)
    end
  end
  
  describe "confirmation" do
    test "deliver_user_confirmation_instructions/2 sends token" do
      user = user_fixture(%{confirmed_at: nil})
      
      token = extract_user_token(fn url -> 
        Accounts.deliver_user_confirmation_instructions(user, url)
      end)
      
      assert is_binary(token)
      assert byte_size(token) > 10
    end
    
    test "deliver_user_confirmation_instructions/2 returns error for confirmed user" do
      user = user_fixture()
      # Confirm the user first
      confirmed_user = %{user | confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}
      
      assert {:error, :already_confirmed} = 
        Accounts.deliver_user_confirmation_instructions(confirmed_user, fn _ -> "url" end)
    end
    
    test "confirm_user/1 with valid token confirms user" do
      user = user_fixture(%{confirmed_at: nil})
      
      token = extract_user_token(fn url -> 
        Accounts.deliver_user_confirmation_instructions(user, url)
      end)
      
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.id == user.id
    end
    
    test "confirm_user/1 with invalid token returns error" do
      assert :error = Accounts.confirm_user("invalid_token")
    end
  end
  
  describe "password reset" do
    test "deliver_user_reset_password_instructions/2 sends token" do
      user = user_fixture()
      
      token = extract_user_token(fn url -> 
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)
      
      assert is_binary(token)
      assert byte_size(token) > 10
    end
    
    test "get_user_by_reset_password_token/1 returns user for valid token" do
      user = user_fixture()
      
      token = extract_user_token(fn url -> 
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)
      
      assert reset_user = Accounts.get_user_by_reset_password_token(token)
      assert reset_user.id == user.id
    end
    
    test "get_user_by_reset_password_token/1 returns nil for invalid token" do
      assert is_nil(Accounts.get_user_by_reset_password_token("invalid_token"))
    end
    
    test "reset_user_password/2 with valid attributes resets password" do
      user = user_fixture()
      
      token = extract_user_token(fn url -> 
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)
      
      reset_user = Accounts.get_user_by_reset_password_token(token)
      new_password = "new valid password"
      
      assert {:ok, updated_user} = Accounts.reset_user_password(reset_user, %{
        password: new_password,
        password_confirmation: new_password
      })
      
      assert updated_user.hashed_password != user.hashed_password
      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end
    
    test "reset_user_password/2 with invalid attributes returns changeset error" do
      user = user_fixture()
      
      assert {:error, changeset} = Accounts.reset_user_password(user, %{
        password: "short",
        password_confirmation: "short"
      })
      
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end
    
    test "reset_user_password/2 revokes all user tokens" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      
      assert Accounts.get_user_by_session_token(token)
      
      reset_token = extract_user_token(fn url -> 
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)
      
      reset_user = Accounts.get_user_by_reset_password_token(reset_token)
      
      assert {:ok, _} = Accounts.reset_user_password(reset_user, %{
        password: "new valid password",
        password_confirmation: "new valid password"
      })
      
      refute Accounts.get_user_by_session_token(token)
    end
  end
  
  # Helper functions
  
  defp valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      username: "user#{:rand.uniform(999999)}",
      password: "hello world!"
    })
  end
  
  defp extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end