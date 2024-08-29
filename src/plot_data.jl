
using Plots

#colors() = [:red, :blue, :green, :yellow, :silver, :orange, :brown, :pink, :cyan, :magenta, :gray, :lime, :olive]

# plot a subset of columns
# use N:N to plot the Nth column
function plt(df,indices; mm = true, trend = true)
    plot(map(indices) do i 
        months, demands = df[!,1], df[!,i]
        p = bar(months,demands, smooth = true, label = names(df)[i]*"($i)")
        if mm plot!(p,months, ma(df,i), color = :black, width = 3, label = "mm") end
        if trend
            c = lr(df,i)
            plot!(p,[df[1,1],df[end,1]], [c[2], c[2]+c[1]*(length(months)-1)], color = :red, width = 3, label = "trend")
        end
        return p
    end ..., layout = (length(indices),1))
end


# histogram a subset of columns
function hist(df,indices)
    plot(map(indices) do i 
        demands = df[!,i]
        p = histogram(demands, label = names(df)[i]*"($i)")
        return p
    end ..., layout = (length(indices),1))
end
