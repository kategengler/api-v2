defmodule CanvasAPI.Team do
  @moduledoc """
  A group of users in a Slack team.
  """

  use CanvasAPI.Web, :model

  alias CanvasAPI.ImageMap

  @type t :: %__MODULE__{}

  schema "teams" do
    field :domain, :string
    field :images, :map, default: %{}
    field :name, :string
    field :slack_id, :string

    many_to_many :accounts, CanvasAPI.Account, join_through: "users"
    has_many :canvases, CanvasAPI.Canvas
    has_many :users, CanvasAPI.User
    has_many :oauth_tokens, CanvasAPI.OAuthToken

    timestamps()
  end

  @doc """
  Builds a creation changeset based on the `struct` and `params`.
  """
  @spec create_changeset(%__MODULE__{}, map, Keyword.t) :: Ecto.Changeset.t
  def create_changeset(struct, params, type: :slack) do
    struct
    |> cast(params, [:domain, :name, :slack_id])
    |> validate_required([:domain, :name, :slack_id])
    |> prevent_domain_change
    |> unique_constraint(:domain)
    |> put_change(:images, ImageMap.image_map(params))
  end

  def create_changeset(struct, params, type: :personal) do
    struct
    |> cast(params, [])
    |> put_change(:name, "Notes")
  end

  @doc """
  Builds a changeset for updating a team (only domain, only personal).
  """
  @spec update_changeset(%__MODULE__{}, map) :: Ecto.Changeset.t
  def update_changeset(struct, params) do
    struct
    |> cast(params, [:domain])
    |> if_slack(&prevent_domain_change/1)
    |> validate_required([:domain])
    |> lowercase_domain
    |> validate_domain_format
    |> prefix_domain
    |> unique_constraint(:domain)
  end

  @doc """
  Fetches the OAuth token for the given team and provider.
  """
  def get_token(team, provider) do
    from(assoc(team, :oauth_tokens), where: [provider: ^provider])
    |> first
    |> Repo.one
    |> case do
      nil -> {:error, :token_not_found}
      token -> {:ok, token}
    end
  end

  defp if_slack(changeset, func) do
    if changeset.data.slack_id || get_change(changeset, :slack_id) do
      func.(changeset)
    else
      changeset
    end
  end

  defp prevent_domain_change(changeset) do
    if changeset.data.slack_id do
      changeset
      |> add_error(:domain, "can not be changed for Slack teams")
    else
      changeset
    end
  end

  defp prefix_domain(changeset) do
    domain = "~#{get_change(changeset, :domain)}"
    put_change(changeset, :domain, domain)
  end

  defp lowercase_domain(changeset) do
    case get_change(changeset, :domain) do
      "" <> domain -> put_change(changeset, :domain, String.downcase(domain))
      _ -> changeset
    end
  end

  defp validate_domain_format(changeset) do
    changeset
    |> validate_format(:domain, ~r/\A[a-z0-9][a-z0-9-]{0,34}[a-z0-9]\z/,
         message: """
                  must be between 2 and 36 characters, contain only letters, \
                  numbers, and dashes, and begin and end with a letter or \
                  number\
                  """)
  end
end
