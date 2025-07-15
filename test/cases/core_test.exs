defmodule Aurora.Ctx.Test.Cases.CoreTest do
  use Aurora.Ctx.Test.RepoCase

  alias Aurora.Ctx.Core
  alias Aurora.Ctx.Repo
  alias Aurora.Ctx.Test.Support.Inventory.Product

  test "Test create function" do
    {:ok, product} =
      Core.create(
        Repo,
        Product,
        %{"reference" => "item_1", "name" => "This is item 1", "cost" => 11.12}
      )

    assert product.reference == "item_1"
  end

  test "Test get functions" do
    %{id_1: item_1, id_2: item_2, id_3: item_3} = create_sample_products(3)

    assert Core.get(Repo, Product, item_1.id).reference == "item_1"
    assert Core.get!(Repo, Product, item_2.id).reference == "item_2"
    assert Core.get!(Repo, Product, item_3.id).reference != "item_2"
    assert Core.get(Repo, Product, 1005) == nil
    assert_raise(Ecto.NoResultsError, fn -> Core.get!(Repo, Product, 1005) end)
  end

  test "Test delete functions" do
    items = create_sample_products(3)

    {:ok, deleted_item_2} = Core.delete(Repo, items.id_2)
    assert deleted_item_2.reference == "item_2"

    assert_raise(Ecto.StaleEntryError, fn -> Core.delete(Repo, items.id_2) end)

    {:ok, deleted_item_3} = Core.delete(Repo, items.id_3)
    assert deleted_item_3.reference == "item_3"

    assert_raise(Ecto.StaleEntryError, fn -> Core.delete(Repo, items.id_3) end)
  end

  test "Test update function" do
    items = create_sample_products(2)

    {:ok, update_item_1} =
      Core.update(Repo, items.id_1, %{description: "FIRST UPDATE test item_1"})

    assert update_item_1.description == "FIRST UPDATE test item_1"

    {:error, _} =
      Core.update(Repo, items.id_1, %{description: "SECOND UPDATE test item_1", cost: -1})

    {:ok, _} = Core.delete(Repo, items.id_2)

    assert_raise(Ecto.StaleEntryError, fn ->
      Core.update(Repo, items.id_2, %{description: "FIRST UPDATE test item_2"})
    end)

    items.id_1
    |> Core.change(%{description: "SECOND UPDATE test item_1"})
    |> then(&Core.update(Repo, &1))
    |> tap(&assert(elem(&1, 0) == :ok))
    |> elem(1)
    |> tap(&assert(&1.description == "SECOND UPDATE test item_1"))
  end

  test "Test new function" do
    Repo
    |> Core.new(Product)
    |> tap(&assert(&1.name == nil))
    |> tap(&assert(&1.product_transactions.__struct__ == Ecto.Association.NotLoaded))

    Repo
    |> Core.new(Product, %{name: "First name", reference: "item_chg_01", description: "The item"})
    |> tap(&assert(&1.name == "First name"))
    |> tap(&assert(&1.product_transactions.__struct__ == Ecto.Association.NotLoaded))

    Repo
    |> Core.new(Product, preload: :product_transactions)
    |> tap(&assert(&1.name == nil))
    |> tap(&assert(&1.product_transactions == []))

    Repo
    |> Core.new(Product, %{name: "First name", reference: "item_chg_01", description: "The item"},
      preload: :product_transactions
    )
    |> tap(&assert(&1.name == "First name"))
    |> tap(&assert(&1.product_transactions == []))
  end

  test "Test change function" do
    %Product{}
    |> Core.change()
    |> tap(&assert(Ecto.Changeset.get_field(&1, :reference) == nil))
    |> Core.change(%{reference: "item_chg_01"})
    |> tap(&assert(Ecto.Changeset.get_field(&1, :reference) == "item_chg_01"))
  end

  test "Test list function" do
    items = create_sample_products(100)

    items_read = Core.list(Repo, Product)
    assert(Enum.count(items_read) == Enum.count(items))
  end

  test "Test list filter functionality - where and or_where" do
    create_sample_products(100)

    assert(Repo |> Core.list(Product, where: {:reference, "item_001"}) |> Enum.count() == 1)

    assert(Repo |> Core.list(Product, where: {:reference, :eq, "item_090"}) |> Enum.count() == 1)

    assert(
      Repo |> Core.list(Product, where: [{:reference, :gt, "item_090"}]) |> Enum.count() == 10
    )

    assert(
      Repo |> Core.list(Product, where: [{:reference, :ge, "item_090"}]) |> Enum.count() == 11
    )

    assert(
      Repo |> Core.list(Product, where: [{:reference, :lt, "item_090"}]) |> Enum.count() == 89
    )

    assert(
      Repo |> Core.list(Product, where: [{:reference, :le, "item_090"}]) |> Enum.count() == 90
    )

    assert(
      Repo
      |> Core.list(Product, where: {:reference, :between, "item_090", "item_095"})
      |> Enum.count() == 6
    )

    assert(
      Repo
      |> Core.list(Product,
        where: {:reference, :between, "item_090", "item_095"},
        or_where: {:reference, :eq, "item_001"}
      )
      |> Enum.count() == 7
    )
  end

  test "Test list bare pagination" do
    create_sample_products(100)

    assert(
      Repo
      |> Core.list(Product, paginate: %{page: 1, per_page: 10})
      |> Enum.count() == 10
    )
  end

  test "Test bare count" do
    create_sample_products(100)

    assert(Core.count(Repo, Product, paginate: %{page: 1, per_page: 10}) == 100)

    assert(
      Core.count(Repo, Product,
        paginate: %{page: 1, per_page: 10},
        where: {:reference, :between, "item_005", "item_015"}
      ) == 11
    )
  end

  test "Test List pagination " do
    create_sample_products(100)

    Repo
    |> Core.list_paginated(Product, paginate: %{per_page: 5})
    |> tap(&(assert(&1.entries_count) == 100))
    |> tap(&(assert(&1.pages_count) == 10))
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_001"))
    |> tap(&assert(List.last(&1.entries).reference == "item_005"))
    |> Core.next_page()
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_006"))
    |> tap(&assert(List.last(&1.entries).reference == "item_010"))
    |> Core.previous_page()
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_001"))
    |> tap(&assert(List.last(&1.entries).reference == "item_005"))
    ## Should stay in the same page since there are only
    |> Core.to_page(30)
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_001"))
    |> tap(&assert(List.last(&1.entries).reference == "item_005"))
    |> Core.to_page(11)
    |> tap(&assert(Enum.count(&1.entries) == 5))
    |> tap(&assert(List.first(&1.entries).reference == "item_051"))
    |> tap(&assert(List.last(&1.entries).reference == "item_055"))
  end

  test "Test list sorting" do
    create_sample_products(100)

    Repo
    |> Core.list(Product, order_by: [asc: :reference])
    |> tap(&assert(List.first(&1).reference == "item_001"))

    Repo
    |> Core.list(Product, order_by: [desc: :reference])
    |> tap(&assert(List.first(&1).reference == "item_100"))
  end

  test "Test get_by function" do
    create_sample_products(100)

    Repo
    |> Core.get_by(Product, reference: "item_100")
    |> tap(&assert(&1.reference == "item_100"))

    Repo
    |> Core.get_by(Product, [], where: [reference: "item_098"])
    |> tap(&assert(&1.reference == "item_098"))
  end
end
