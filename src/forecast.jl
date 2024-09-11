
# utility function to add a forecast to a dataframe
# the function must return a tuple with the forecast and the deviation
# they are added to a column with the name of the forecast and DEV_ prefix
add_forecast!(forecast_func, df, fcol) = transform!(df, :ITEM => ByRow(forecast_func) => [fcol, "DEV_"*fcol])

# Add a moving average forecast to items based on the demand (last months) and for the lat month
# items = dataframe of items
# demand = dataframe of demand (months x items)
# fname = name of the forecast, colums will be fname for the value and DEV_fname for the deviation
# window = window for the average
function add_ma_forecast!(items, demand, fcol = "MA", window = 12)    
    add_forecast!(items, fcol) do item
        data = demand[end-window-1:end-1,item]
        (round(Int,mean(data)),std(data))
    end
end