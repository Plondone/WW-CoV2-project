# Plots standard curve for a given file (make sure it has quantities and targets and it is standard curve data)

source('./general_functions.R') # Source the general_functions file before running this

# User inputs ----
# choose file name, in the same directory as Rproject
flnm <- 'WW20_622_N1-N2'  # set the filename
flpath <- str_c('excel files/',flnm,'.xls') # this completes the file path

title_name <- 'qPCR Standard curve 11: N1-N2 multiplex'

# Data input ----

fl <- readqpcr(flpath) # read file

# Bring sample names from template google sheet
plate_template_raw <- read_sheet('https://docs.google.com/spreadsheets/d/19oRiRcRVS23W3HqRKjhMutJKC2lFOpNK8aNUkC-No-s/edit#gid=478762118', sheet = 'Plate import setup', range = 'G1:S9')
plate_template <- read_plate_to_column(plate_template_raw, 'Sample Name') # convert plate template (sample names) into a single vector, columnwise

sample_order = columnwise_index(fl) # this gives a vector to order the samples columnwise in the PCR plate or strip (by default : data is shown row-wise) => This command will enable plotting column wise order

bring_results <- fl$Results %>% select(`Well Position`, `Sample Name`, CT, starts_with('Tm'),`Target Name`, Task) %>% rename(Target = `Target Name`) %>%  .[sample_order,] %>%  # select only the results used for plotting, calculations etc. and arrange them according to sample order
  select(-`Sample Name`) %>% right_join(plate_template, by = 'Well Position') %>%  # Incorporate samples names from the google sheet by matching well position
  separate(`Sample Name`, c(NA, NA, 'Quantity'), sep = '-|_') %>% mutate_at('Quantity', ~ replace_na(as.numeric(.), 0)) %>% 
  filter(!is.na(Target))

# optional filtering to remove low concentration points in standard curve
# bring_results %<>% filter(Quantity > 1| Quantity == 0) # filtering only standard curve within the linear range

# plotting ----

plt <- plotstdcurve(bring_results, title_name, 'log(Copy #)') # plot standard curve

# # Extract the names of the targets in use
# targets_used <- fl$Results %>% filter(Task == 'STANDARD') %>% pull(`Target Name`) %>% unique(.)  

# Isolating standard curve variables (Quantity,CT) of the different targets into groups
standard_curve_vars <- bring_results %>% filter(Task == 'STANDARD')  %>% select(Quantity, CT, Target) %>% group_by(Target) # select required columns and group

# Apply linear regression and find the model fitting results (equation and slope, R2 values) for each target
std_table <- standard_curve_vars %>% do(., equation = lm_std_curve(.), params = lm_std_curve(., trig = 'coeff'), dat = .[1,] ) # "do" applies functions to each group of the data
std_table$params %<>% bind_rows() # Convert parameters and data into tibbles : "do" function makes htem lists
std_table$dat %<>% bind_rows()  

std_table$dat$CT <- max(standard_curve_vars$CT, na.rm = T) - 2 * seq_along(std_table$Target) + 2 # manual numbering for neat labelling with geom_text

# Add labels to plot - linear regression equation
plt + geom_text(data = std_table$dat, label = std_table$equation, parse = TRUE, show.legend = F, hjust = 'inward', nudge_x = 0, force = 10)
# ggsave(str_c('qPCR analysis/', flnm, '_subset', '.png'), width = 5, height = 4)

# processing linear regression out
efficiency_table <- tibble(Slope = std_table$params %>% pull(slope), y_intercept = std_table$params %>% pull(y_intercept) , Efficiency = 10^(-1/Slope), '% Efficiency' = (Efficiency -1)*100 , 'R-square' = std_table$params %>% pull(r_square) %>% round(2))
rownames(efficiency_table) <- std_table$dat$`Target`
View(efficiency_table)
