defmodule NathanForUsWeb.UserRegistrationController do
  use NathanForUsWeb, :controller

  alias NathanForUs.Accounts
  alias NathanForUs.Accounts.User
  alias NathanForUsWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    
    conn
    |> assign(:page_title, "Join Nathan For Us")
    |> assign(:page_description, "Sign up to join a group of like minded people and stay tuned for Nathan Fielder updates")
    |> render(:new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)
        |> redirect(to: ~p"/stay-tuned")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> assign(:page_title, "Join Nathan For Us")
        |> assign(:page_description, "Sign up to join a group of like minded people and stay tuned for Nathan Fielder updates")
        |> render(:new, changeset: changeset)
    end
  end
end
