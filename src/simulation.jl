using Dates
using DataFrames
using DataStructures

# simulation of inventory for an item based on functions handling sales orders and purchase orders
#
# item: the item to simulate
#
# inventory_data: store inventory information and used by following functions
# initial_inventory(item,inventory_data) -> returns (start date, onhand, onorder, backlog) for this item
# update_inventory!(item,date,onhand,onorder,backlog,inventory_data) -> update the inventory information for this item
#
# sales_data: store sales order information and used by following functions
# next_sales_date(item,date,sales_data) -> returns the next sales date for this item after date
# get_sales(item,date,sales_data) -> returns a list of (sales_order, ordered_quantity, backordered_quantity) for this item on date, if backordered_quantity > 0, it is an older backorder
# update_sales!(sales_order,quantity,date,sales_data) -> update the sales order with the quantity delivered
#
# purchase_data: store purchase order information and used by following functions
# next_order_date(item,date,purchase_data) -> returns the next ordering date for this item after date (for continuous replenishment, it may be the next day)
# get_order(item,date,onhand,onorder,backlog,sales_data,purchase_data) -> returns the quantity ordered for this item on date
#                                                             sales_data is sales information
#                                                             onhand, onorder, backlog are the current inventory position
#                                                             they are used for simulating replenishement as opposed to historical orders
#                                                             sales_data can be modified to store the forecast, it should not peek in the future....                                                  
# next_receipt_date(item,date,purchase_data) -> returns the next receiving date for this item after date
# get_receipt(item,date,purchase_data) -> returns (received,ordered) the quantity received for this item on date 
#
# log: 0 no log, 1 log item, 2 +day, 3 +activities
# alldays: record inventory all days even if no change                                                                                                     
#
function simulate_inventory(item,
                            inventory_data, initial_inventory, update_inventory!,
                            sales_data, next_sales_date, get_sales, update_sales!,
                            purchase_data, next_order_date, get_order, next_receipt_date, get_receipt;
                            log = 0, alldays = false)
    
    
    log > 0 && println("Simulating inventory for item $item")

    # get the start date and inventory position for this item, this is the inventory at the end of the day after any activity this day
    current_date, onhand, onorder, backlog = initial_inventory(item,inventory_data)
    #@show current_date, onhand, onorder, backlog
 
    sales_date = order_date = receipt_date = current_date
    while true
        change = false

        # update the activity dates
        sales_date <= current_date && (sales_date = next_sales_date(item,current_date,sales_data))
        order_date <= current_date && (order_date = next_order_date(item,current_date,purchase_data))
        receipt_date <= current_date && (receipt_date = next_receipt_date(item,current_date,purchase_data))

        # move to next activity date
        previous_date = current_date
        current_date = min(sales_date,order_date,receipt_date)
        current_date == typemax(Date) && break

        # record all days if required
        if alldays
            for d in previous_date+Day(1):current_date-Day(1)
                update_inventory!(item,d,onhand,onorder,backlog,inventory_data)
            end
        end

        log > 1 && println("Processing day $current_date")

        # ordering
        if order_date == current_date
            ordered = get_order(item,current_date,onhand, onorder, backlog,sales_data, purchase_data)
            if ordered > 0
                onorder += ordered
                change = true
                log > 2 && println("Purchase: ordered $ordered, onorder $onorder")
            end
        end

        # reception
        if receipt_date == current_date
            received = get_receipt(item, current_date, purchase_data)
            if received > 0
                onhand += received
                onorder -= received
                change = true
                log > 2 && println("Purchase: received $received, onhand $onhand, onorder $onorder")
            end
        end

        # process sales orders also when there was inbound purchase as there could be pending back orders
        # sales are processed even onhand is 0, to ensure they are backordered
        for (sales_order,ordered_quantity,backordered_quantity) in get_sales(item,current_date,sales_data)
            is_backorder = backordered_quantity > 0
            q = min(onhand, is_backorder ? backordered_quantity : ordered_quantity)
            onhand -= q
            backlog +=  (is_backorder ? 0 : ordered_quantity) - q
            update_sales!(sales_order,q,current_date,sales_data)
            change = true
            log > 2 && println("Sales: ordered $ordered_quantity backordered $backordered_quantity, delivered $q, onhand $onhand, backlog $backlog")
        end

        # record inventory if changed
        if change || alldays
            update_inventory!(item,current_date,onhand,onorder,backlog,inventory_data)
        end
    end
end

# helpers function to simulate inventory with a dataframe having DATE, ITEM, INV_ONHAND, INV_ONORDER, INV_BACKORDER
function df_initial_inventory(item,df_inventory)
    row = last(filter(row -> row.ITEM == item, eachrow(df_inventory)))
    return row.DATE, row.INV_ONHAND, row.INV_ONORDER, row.INV_BACKORDER
end

function df_update_inventory!(ITEM,DATE,INV_ONHAND,INV_ONORDER,INV_BACKORDER,df_inventory)
    push!(df_inventory, (;ITEM,DATE,INV_ONHAND,INV_ONORDER,INV_BACKORDER)) # use named tuple from variable names, so cool !
end

# helpers function to simulate sales with a dataframe having ITEM, ORDER_DATE, ORDER_QUANTITY, ON_HAND_QUANTITY, LAST_DELIVERY_DATE, REMAINING_QUANTITY
# sales_data is a list with the data frame, the current item and a list of cached orders to accelerate the process

# return the date of the next sales order after the date or typemax(Date)
function df_next_sales_date(item,date,sales_data)
    df_sales, citem, orders = sales_data
    if item != citem
        # add missing columns in the sales data if needed
        if !(:ON_HAND_QUANTITY in names(df_sales)) df_sales.ON_HAND_QUANTITY = missings(Int,nrow(df_sales)) end
        if !(:LAST_DELIVERY_DATE in names(df_sales)) df_sales.LAST_DELIVERY_DATE = missings(Date, nrow(df_sales)) end
        if !(:REMAINING_QUANTITY in names(df_sales)) df_sales.REMAINING_QUANTITY .= 0 end
        orders = [row  for row in  eachrow(df_sales) if row.ITEM == item && (row.ORDER_DATE > date || row.REMAINING_QUANTITY > 0)]
        sort!(orders, by = row -> (row.ORDER_DATE))
        sales_data[2] = item
        sales_data[3] = orders
    end
    index = findfirst(row -> Date(row.ORDER_DATE) > date, orders)
    # @show index, length(orders)
    return isnothing(index) ? typemax(Date) : Date(orders[index].ORDER_DATE)
end

function df_get_sales(item,date,sales_data)
    orders = sales_data[3]
    # @show  date length(orders) [row.ORDER_DATE for row in orders]
    index = findlast(row -> Date(row.ORDER_DATE) <= date, orders)
    return isnothing(index) ? [] : [(row, row.ORDERED_QUANTITY, row.REMAINING_QUANTITY) for row in orders[1:index]]
end


function df_update_sales!(sales_row,quantity,date,sales_data)
    #@show sales_row quantity date
    # not a backorder, update the quantity delivered on hand and remaining
    if date == Date(sales_row.ORDER_DATE)
        sales_row.ON_HAND_QUANTITY = quantity
        sales_row.REMAINING_QUANTITY = sales_row.ORDERED_QUANTITY
    end
    sales_row.LAST_DELIVERY_DATE = date
    sales_row.REMAINING_QUANTITY -= quantity
    # if a row is fully delivered, remove it from the list, it's the first
    if sales_row.REMAINING_QUANTITY == 0
        popfirst!(sales_data[3])
    end
end

# helpers function to simulate purchase with a dataframe of historical purchases having ITEM_CODE, ORDER_DATE, ORDERED_QUANTITY, DELIVERY_DATE, DELIVERED_QUANTITY
# purchase_data is a list with the data frame, the current item and lists of cached orders to accelerate the process
function df_next_order_date(item,date,purchase_data)
    df_delivery, citem, orders,_,_ = purchase_data
    if citem != item
        # create a list of ordering rows for this item
        orders = [row for row in eachrow(df_delivery) if row.ITEM_CODE == item && row.ORDER_DATE > date && row.ORDERED_QUANTITY > 0]
        sort!(orders, by = row -> (row.ORDER_DATE))
        purchase_data[2] = item
        purchase_data[3] = orders
    end

    # find the first date after date in orders
    for row in orders
        if row.ORDER_DATE > date return row.ORDER_DATE end
    end
    return typemax(Date)
end

function df_get_order(item,date,onhand,onorder,backlog,sales_data,purchase_data)
    # could be improved by removing orders from the list
    return sum(row.ORDERED_QUANTITY for row in purchase_data[3] if row.ORDER_DATE == date)
end

function df_next_receipt_date(item,date,purchase_data)
    df_delivery, _, _, citem, receipts = purchase_data
    #@show item date citem
    if citem != item
        # create a list of receipts rows for this item
        receipts = [row for row in eachrow(df_delivery) if row.ITEM_CODE == item && !ismissing(row.DELIVERY_DATE) && row.DELIVERY_DATE > date && row.DELIVERED_QUANTITY > 0]
        sort!(receipts, by = row -> (row.DELIVERY_DATE))
        purchase_data[4] = item
        purchase_data[5] = receipts
        #@show receipts
    end

    # find the first date after date in receipts
    for row in receipts
        if row.DELIVERY_DATE > date return row.DELIVERY_DATE end
    end
    return typemax(Date)
end

function df_get_receipt(item,date,purchase_data)
    # could be improved by removing receipts from the list
    return sum(row.DELIVERED_QUANTITY for row in purchase_data[5] if row.DELIVERY_DATE == date)
end

function simulate_items(df_supply, df_delivery; ritem = r".*", log=0, alldays = false)

    # set of items filter with the regexp
    items = Set(filter(x -> occursin(ritem,x), df_supply.ITEM))
    # create a 0 start inventory at first order day for each item in the supply data
    df_s = subset(df_supply, :ITEM => ByRow(in(items)))
    #@show size(df_s) df_s[1:5,:]
    df_inventory = combine(groupby(df_s, :ITEM), :ORDER_DATE => (dt->minimum(Date.(dt)-Day(1))) => :DATE)
    # reorder date in first column
    df_inventory = select(df_inventory, :DATE, :ITEM)
    df_inventory.INV_ONHAND .= 0
    df_inventory.INV_ONORDER .= 0
    df_inventory.INV_BACKORDER .= 0
    #@show df_inventory
 
    for item in items
        simulate_inventory(item,
                            df_inventory, df_initial_inventory, df_update_inventory!,
                            [df_supply,"",[]], df_next_sales_date, df_get_sales, df_update_sales!,
                            [df_delivery,"",[],"",[]], df_next_order_date, df_get_order, df_next_receipt_date, df_get_receipt;
                            log, alldays)
    end
    return df_inventory
end