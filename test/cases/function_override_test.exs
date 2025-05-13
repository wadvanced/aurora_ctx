defmodule Aurora.Ctx.Test.Cases.FunctionOverrideTest do
  use Aurora.Ctx.Test.RepoCase

  alias Aurora.Ctx.Test.Support.Inventory.Product

  defmodule Inventory do
    use Aurora.Ctx

    @ctx_repo_module Aurora.Ctx.Repo

    ctx_register_schema(Product)

    @spec create_product(map) :: Ecto.Schema.t()
    def create_product(attrs \\ %{}) do
      modified_attrs =
        attrs
        |> Map.put("deleted", false)
        |> Map.put_new("description", attrs["name"])

      %Product{}
      |> Product.changeset(modified_attrs)
      |> Repo.insert()
    end
  end

  test "Test create function" do
    context = __MODULE__.Inventory

    %{"reference" => "item_001", "name" => "This is item 001", "cost" => 11.12, "deleted" => true}
    |> context.create_product()
    |> tap(&assert(elem(&1, 0) == :ok))
    |> elem(1)
    |> tap(&assert(&1.reference == "item_001"))
    |> tap(&assert(&1.deleted == false))
    |> tap(&assert(&1.description == &1.name))
  end
end
