import XLSX
include("read_data.jl")


# conversion to DB Inventory demo format


function convert(filename, ritems = r".*")
    df_items = read_items()
    println("Items: ",size(df_items))
    df_supply = read_supply()
    println("Supply: ",size(df_supply))
    df_delivery = read_delivery()
    println("Delivery: ",size(df_delivery)) 
  
    subset!(df_items, :ITEM => ByRow(i->!isnothing(match(ritems, i))))
    println("Filtered Items: ",size(df_items))
    items = intersect(df_items[!,:ITEM],df_supply[!,:ITEM])
    subset!(df_supply, :ITEM => ByRow(in(items)))
    println("Filtered Supply: ",size(df_supply))
    subset!(df_items, :ITEM => ByRow(in(items)))
    println("Filtered Items: ",size(df_items))
    subset!(df_delivery, :ITEM_CODE => ByRow(in(items)))
    println("Filtered Delivery: ",size(df_delivery))
    println()

    # products & SKU
    df_products = select(df_items, :ITEM => :id, :DESCRIPTION => :name)
    df_products[!,"productType.id"] .= "SPARE"
    df_skus = select(df_items, :ITEM => "product.id")
    df_skus[!,"warehouse.id"] .= "HLMY"
    println("Products: ",size(df_products))

    # Historical sales
    df_sales = select(df_supply,:ORDER_DATE => ByRow(Date) => :creationDate, :ORDER_DATE => ByRow(Date) => :dueDate, :ORDERED_QUANTITY => :quantity, :ITEM => "sku.product.id")
    df_sales[!,"id"] = 1:nrow(df_sales)
    df_sales[!,"customer.id"] .= "DEALER"
    df_sales[!,"sku.warehouse.id"] .= "HLMY"
    println("Sales: ",size(df_sales))

    # Historical purchase orders creationDate	deliveryDate	id	quantity	sku.product.id	sku.warehouse.id
    subset!(df_delivery, :DELIVERY_DATE => ByRow(!ismissing))
    subset!(df_delivery, :ORDERED_QUANTITY => ByRow(>(0 )))
    df_orders = select(df_delivery,:PURCHASE_ORDER => :id, :ORDER_DATE => :creationDate, :DELIVERY_DATE => :deliveryDate, :ORDERED_QUANTITY => :quantity, :ITEM_CODE => "sku.product.id")
    df_orders[!,"sku.warehouse.id"] .= "HLMY"
    println("Orders: ",size(df_orders))

    # Unitial inventory date	quantity	sku.product.id	sku.warehouse.id
    df_inventory = select(df_skus, "product.id" => "sku.product.id", "warehouse.id" => "sku.warehouse.id")
    df_inventory[!,"quantity"] .= 0
    df_inventory[!,"date"] .= Date(2022,1,1) 
    println("Inventory: ",size(df_inventory))

    # write all to the file
    println("updating file: $filename")
    XLSX.openxlsx(filename, mode="rw") do xf
        function update(name,df)
            sh = XLSX.hassheet(xf,name) ? xf[name] : XLSX.addsheet!(xf, name)
            # empty the sheet
            sz = size(sh[:])
            for i in 1:sz[1]
                for j in 1:sz[2]
                    sh[i,j] = missing
                end
            end
            # add the data
            println("Updating $name")
            XLSX.writetable!(sh, df)
        end

        update("Product", df_products)
        update("Sku", df_skus)
        update("HistoricalSalesOrder", df_sales)
        update("HistoricalPurchaseOrder", df_orders)
        update("InitialInventory", df_inventory)
    end
    println("Update completed")
end


convert("$rootdata/HLYM Spare Parts MD.xlsx", r"MD.*")
