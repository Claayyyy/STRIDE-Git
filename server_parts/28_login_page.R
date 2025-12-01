# Login Page

### ENHANCED LOGIN PAGE ####

# Reactive value to track the user's status: "unauthenticated", "login", "register", "authenticated"
user_status <- reactiveVal("unauthenticated")

# 💡 NEW: Reactive value to store the username after successful authentication
authenticated_user <- reactiveVal(NULL)

# Reactive value to hold the user's choice: "login" or "register"
form_choice <- reactiveVal("login")  

# Reactive value to trigger a database refresh
db_trigger <- reactiveVal(0)  

# Reactive value to hold the user database
user_database <- reactive({
  # Depend on the trigger. Every time db_trigger changes, this runs.
  db_trigger()  
  
  # Read data from Google Sheet
  users_db <- tryCatch({
    googlesheets4::read_sheet(sheet_url)
  }, error = function(e) {
    showNotification(paste("Error reading database:", e$message,  
                           "Assuming sheet structure is correct."), type = "error")
    # Return an empty dataframe with correct structure on error to prevent crashing
    # Ensure 'Station' column is included
    return(data.frame(Email_Address = character(), Password = character(), Station = character())) 
  })
  
  return(users_db)
})

observe({
  
  # --- Part A: Check if required fields are filled ---
  
  # List the IDs of all inputs that MUST be filled out.
  # Optional fields are not included here.
  required_inputs <- c(
    "school_id",
    "school_head_contact",
    "school_head_email"
  )
  
  # This checks that each required input is not empty or NULL.
  # It returns TRUE only if all required fields have a value.
  all_filled <- all(sapply(required_inputs, function(id) {
    !is.null(input[[id]]) && input[[id]] != ""
  }))
  
  # --- Part B: Check if the inputs have the correct format ---
  
  # We use `isTRUE()` to safely handle potential errors (like NA) from checks.
  # It treats anything that isn't exactly TRUE as FALSE.
  
  # Validate School ID: must be a number and have the correct length.
  school_id_ok <- isTRUE(
    !is.na(as.numeric(input$school_id)) &&                # Is it a number?
      nchar(as.character(input$school_id)) == 6 # Is it the right length?
  )
  
  # Validate Primary Contact: must be a number and have the correct length.
  contact_ok <- isTRUE(
    !is.na(as.numeric(input$school_head_contact)) &&
      nchar(as.character(input$school_head_contact)) == 11
  )
  
  # Validate Alternate Contact: it's valid if it's empty OR if it meets the format rules.
  contact_alt_ok <- isTRUE(
    input$school_head_contact_alt == "" || # It's okay if empty
      (
        !is.na(as.numeric(input$school_head_contact_alt)) &&
          nchar(as.character(input$school_head_contact_alt)) == 11
      )
  )
  
  # Validate Primary Email: must contain "@deped.gov.ph".
  email_ok <- isTRUE(grepl("@deped.gov.ph", input$school_head_email))
  
  # Validate Alternate Email: it's valid if it's empty OR if it meets the format rules.
  email_alt_ok <- isTRUE(
    input$school_head_email_alt == "" || # It's okay if empty
      grepl("@", input$school_head_email_alt)
  )
  
  # Combine all format checks. This will be TRUE only if every single check above is TRUE.
  all_correct <- school_id_ok && contact_ok && contact_alt_ok && email_ok && email_alt_ok
  
  # --- Part C: Enable or Disable the Submit Button ---
  
  # The button is enabled only if all required fields are filled AND all formats are correct.
  if (all_filled && all_correct) {
    shinyjs::enable("submit")
  } else {
    shinyjs::disable("submit")
  }
})

# --- UI Rendering Logic ---

# Main dynamic UI switch
# 1️⃣  Define the reusable UI function FIRST
login_register_UI <- function(id) {
  ns <- NS(id)
  
  tagList(
    tags$script(HTML("
      $(document).on('keyup', function(e) {
        if (e.key === 'Enter' || e.keyCode === 13) {
          
          // --- 1. GUEST MODAL (Highest Priority) ---
          var guestBtn = $('.btn-enter-guest'); // Look for the class we added
          if (guestBtn.length > 0 && guestBtn.is(':visible')) {
             guestBtn.click();
             e.preventDefault(); 
             return; 
          }

          // --- 2. REGISTER PAGE ---
          // Check if the Register button (with our class) is visible
          var regBtn = $('.btn-enter-register');
          if (regBtn.length > 0 && regBtn.is(':visible')) {
             
             // CHECK: Is the button ENABLED? (User finished answering)
             if (!regBtn.prop('disabled') && !regBtn.hasClass('disabled')) {
                regBtn.click();
             }
             e.preventDefault(); 
             return;
          }

          // --- 3. LOGIN PAGE ---
          // Check if the Login button (with our class) is visible
          var loginBtn = $('.btn-enter-login');
          if (loginBtn.length > 0 && loginBtn.is(':visible')) {
             loginBtn.click();
             e.preventDefault(); 
             return;
          }
        }
      });
    ")),
    # ✅ Animated gradient background (no bubbles)
    div(class = "login-bg gradient-animated"),
    
    # Render the UI produced by the authentication module
    uiOutput(ns("auth_page"))
  )
}



# ... (all the code at the top of the file) ...

# 2️⃣  Define the main dynamic page switch
output$page_ui <- renderUI({
  status <- user_status()
  current_user <- authenticated_user()  # Retrieve logged-in user
  
  # ✅ AUTHENTICATED USERS
  if (status == "authenticated" && !is.null(current_user)) {
    
    # --- 💡 MODIFICATION START ---
    
    # 🟡 Step 1: Check if Guest first
    if (current_user == "guest_user@stride") {
      print("🟢 Guest accessing STRIDE2 dashboard")
      
      showNotification("Welcome to STRIDE (Guest Mode: Read-only Access)", type = "message", duration = 5)
      
      # SHOW THE *REGULAR* MGMT CONTENT
      shinyjs::show("mgmt_content") 
      
      # HIDE all other UIs
      shinyjs::hide("data_input_content")
      shinyjs::hide("main_content")
      
      return(NULL)
    }
    
    # --- 💡 MODIFICATION END ---
    
    
    # 🟢 Step 2: Handle authenticated users from Google Sheet
    users_db <- user_database()
    user_row <- users_db[users_db$Email_Address == current_user, ]
    
    if (nrow(user_row) == 1) {
      station <- user_row$Station[1]
      
      if (station == "Central Office") {
        shinyjs::hide("data_input_content")
        shinyjs::show("mgmt_content") # <-- This is correct
        shinyjs::hide("main_content")
      } else if (station == "School") {
        shinyjs::show("data_input_content")
        shinyjs::hide("main_content")
        shinyjs::hide("mgmt_content")
      } else {
        # ... (rest of your logic) ...
      }
      
      return(NULL)
    }
  }
  
  
  # ✅ UNAUTHENTICATED USERS — show login/register page
  login_register_UI("auth")
})

# ... (rest of the file) ...


# 3️⃣  Activate the authentication module
callModule(authentication_server, "auth", 
           user_status, form_choice, sheet_url, user_database, db_trigger, 
           authenticated_user)


# Pass the new reactive

# --- Main App Module ---

# Handle logout from the main app
observeEvent(input$`main_app-logout`, {
  user_status("unauthenticated")
  authenticated_user(NULL) # 💡 NEW: Clear the authenticated user
  form_choice("login")  
  showNotification("Logged out successfully.", type = "message")
})