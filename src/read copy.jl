using CSV
using DataFrames
using Dates
using Statistics
using LinearRegression
using Plots

colors = [:red, :blue, :green, :yellow, :silver, :orange, :brown, :pink, :cyan, :magenta, :gray, :lime, :olive]

function read()
    df = CSV.read("data/HLYM Demands.csv", DataFrame, transpose=true)
    # convert the Item colun to dates and rename it to Month
    rename!(df, :Item => :Month)
    transform!(df,:Month=>(x->map(x) do d Date(d÷100,d%100) end)=>:Month)
    # transform missings to zeros
    transform!(df, names(df)[2:end] .=> (x->coalesce.(x,0)) .=> names(df)[2:end])
    return df
end

# some infos
function infos(df)
    fs = [minimum, maximum, mean, std, median]
    return vcat(map(fs) do f
        insertcols!(combine(df, names(df)[2:end] .=> f, renamecols = false),1,:function => Symbol(f))
    end ...)
end

# mobile average
ma(df,i,window = 12) = [t <= window ? df[t,i] : round(Int,mean(df[t-window:t-1,i])) for t in eachindex(df[:,i])]

# linear regression (trend)
function lr(df,i)
    return coef(linregress(collect(1:length(df[!,i])),df[!,i]))
end

# plot a subset of columns
# use N:N to plot the Nth column
function plt(df,indices; mm = true, trend = true)
    plot(map(indices) do i 
        months, demands = df[!,1], df[!,i]
        p = bar(months,demands, color = [month(d)%12 == 1 ? :green : :blue for d in months], smooth = true, label = names(df)[i]*"($i)")
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
