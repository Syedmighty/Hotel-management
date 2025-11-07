# Hotel Inventory Management System (HIMS) - User Manual

**Version:** 1.1.0
**Last Updated:** January 2025

---

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Dashboard](#dashboard)
4. [Inventory Management](#inventory-management)
5. [Purchase Management](#purchase-management)
6. [Issue Management](#issue-management)
7. [Supplier Management](#supplier-management)
8. [Recipe Management](#recipe-management)
9. [Stock Transfer](#stock-transfer)
10. [Wastage & Returns](#wastage--returns)
11. [Reports](#reports)
12. [Settings](#settings)
13. [Backup & Restore](#backup--restore)
14. [Troubleshooting](#troubleshooting)

---

## Introduction

HIMS (Hotel Inventory Management System) is a comprehensive, offline-first inventory management solution designed specifically for hotels and restaurants. It helps you track stock, manage purchases, monitor consumption, and generate detailed reports.

### Key Features

- ✅ **Offline-First**: Works without internet connection
- ✅ **Real-Time Stock Tracking**: Monitor inventory levels instantly
- ✅ **Purchase Management**: Record and approve purchases
- ✅ **Department Issues**: Track consumption by department
- ✅ **Recipe Costing**: Calculate recipe costs and profit margins
- ✅ **Comprehensive Reports**: PDF exports for all reports
- ✅ **Automated Backups**: Scheduled database backups
- ✅ **Low Stock Alerts**: Get notified when stock is low
- ✅ **Multi-Location**: Support for multiple storage locations

---

## Getting Started

### First Time Setup

1. **Launch the Application**
   - Open HIMS on your device
   - The app will initialize the database automatically

2. **Configure Company Information**
   - Go to **Settings** → **General**
   - Enter your hotel/restaurant details:
     - Hotel Name
     - Address
     - Phone Number
     - Email
     - GST Number
   - Click **Save Company Information**

3. **Set Up Master Data**
   - Add **Categories** for organizing inventory items
   - Add **Locations** for storage areas (Kitchen, Bar, Store, etc.)
   - Add **Suppliers** with contact details
   - Add **Stock Items** with units and minimum stock levels

4. **Configure Notifications**
   - Go to **Settings** → **Notifications**
   - Enable/disable alerts:
     - Low Stock Alerts
     - Pending Approvals
     - Daily Summary

5. **Set Up Backups**
   - Go to **Settings** → **Backup**
   - Enable **Auto Backup**
   - Choose frequency (Daily/Weekly/Monthly)

---

## Dashboard

The Dashboard provides an at-a-glance view of your inventory status.

### Metrics Displayed

1. **Total Stock Value**: Current value of all inventory
2. **Low Stock Items**: Items below minimum level (with alert icon)
3. **Pending Approvals**: Purchases/issues awaiting approval
4. **Today's Issues**: Total value of items issued today

### Quick Actions

- **Add Purchase**: Record a new purchase
- **Create Issue**: Issue items to departments
- **View Reports**: Access all reports
- **Stock Transfer**: Move stock between locations

### Recent Activities

View the latest transactions:
- Recent Purchases
- Recent Issues
- Recent Transfers

---

## Inventory Management

### Adding Stock Items

1. Go to **Inventory** → **Stock Items**
2. Click **+ Add Item**
3. Fill in the details:
   - **Item Name**: Name of the product
   - **Category**: Select from dropdown
   - **Location**: Default storage location
   - **Unit**: kg, L, pcs, etc.
   - **Minimum Stock**: Alert threshold
   - **Maximum Stock**: Maximum quantity
   - **Reorder Level**: Suggested reorder point
4. Click **Save**

### Viewing Stock

**List View** (Default):
- Shows all items with current stock
- Color-coded indicators:
  - 🔴 Red: Below minimum stock
  - 🟡 Yellow: Near minimum (within 20%)
  - 🟢 Green: Adequate stock

**Search & Filter**:
- Search by item name
- Filter by category
- Filter by location
- Sort by name, stock level, value

### Editing Items

1. Click on any item in the list
2. Edit the details
3. Click **Update**

### Stock Adjustments

For manual adjustments (inventory counts, corrections):
1. Click on the item
2. Select **Adjust Stock**
3. Enter new quantity
4. Add reason for adjustment
5. Confirm

---

## Purchase Management

### Creating a Purchase

1. Go to **Purchases** → **New Purchase**
2. Fill in purchase details:
   - **Supplier**: Select from dropdown
   - **Purchase Date**: Default is today
   - **Invoice Number**: Supplier's invoice number
   - **Payment Mode**: Cash, Card, Credit, UPI
   - **Status**: Pending or Completed

3. Add Items:
   - Click **+ Add Item**
   - Select **Stock Item**
   - Enter **Quantity**
   - Enter **Rate** (per unit)
   - Click **Add**
   - Repeat for all items

4. Review:
   - Check **Subtotal**
   - Add **Discount** (if any)
   - Verify **Total Amount**

5. Click **Save Purchase**

### Purchase Approval Workflow

**For Pending Purchases:**
1. Go to **Purchases** → **Pending**
2. Click on a purchase to review
3. Verify items and amounts
4. Click **Approve** or **Reject**
5. Add approval notes (if needed)

**Approved Purchases:**
- Stock is automatically added
- Supplier balance updated (if credit)
- Purchase becomes read-only

### Viewing Purchase History

1. Go to **Purchases** → **All Purchases**
2. Use filters:
   - Date Range
   - Supplier
   - Payment Mode
   - Status

---

## Issue Management

### Creating an Issue

1. Go to **Issues** → **New Issue**
2. Fill in issue details:
   - **Department**: Kitchen, Bar, Housekeeping, etc.
   - **Issue Date**: Default is today
   - **Issued By**: Your name/username
   - **Purpose**: Reason for issue

3. Add Items:
   - Click **+ Add Item**
   - Select **Stock Item**
   - Enter **Quantity**
   - Rate is auto-filled (FIFO)
   - Click **Add**

4. Click **Save Issue**

### Issue Approval

Similar to purchase approval:
1. Go to **Issues** → **Pending**
2. Review the issue request
3. Click **Approve** or **Reject**
4. Stock is deducted upon approval

### Department Consumption Tracking

View consumption by department:
1. Go to **Reports** → **Issue Report**
2. Select department filter
3. Choose date range
4. View department consumption breakdown

---

## Supplier Management

### Adding a Supplier

1. Go to **Suppliers** → **+ Add Supplier**
2. Fill in details:
   - **Name**: Supplier name
   - **Contact Person**: Primary contact
   - **Phone**: Contact number
   - **Email**: Email address
   - **Address**: Full address
   - **GST Number**: GSTIN
   - **PAN Number**: PAN
3. Click **Save**

### Supplier Ledger

View all transactions with a supplier:
1. Go to **Suppliers**
2. Click on a supplier
3. View:
   - Current Outstanding Balance
   - Purchase History
   - Payment History
   - Credit Purchases

### Managing Payments

**Recording a Payment:**
1. Go to supplier ledger
2. Click **Record Payment**
3. Enter amount
4. Select payment date
5. Add reference (cheque/UPI)
6. Click **Save**

---

## Recipe Management

### Creating a Recipe

1. Go to **Recipes** → **+ Add Recipe**
2. Fill in recipe details:
   - **Dish Name**: Name of the dish
   - **Category**: Starter, Main Course, etc.
   - **Portion Size**: Number of servings
   - **Preparation Time**: In minutes
   - **Selling Price**: Menu price

3. Add Ingredients:
   - Click **+ Add Ingredient**
   - Select **Stock Item**
   - Enter **Quantity** needed
   - Unit is auto-filled
   - Click **Add**
   - Repeat for all ingredients

4. Click **Save Recipe**

### Recipe Costing

The system automatically calculates:
- **Total Cost**: Sum of all ingredients
- **Cost per Serving**: Total cost ÷ portion size
- **Profit per Serving**: Selling price - cost per serving
- **Profit Margin %**: (Profit ÷ Cost) × 100

### Viewing Recipe Costs

1. Go to **Recipes** → **All Recipes**
2. View profit margins:
   - 🟢 Green: >50% margin (High Profit)
   - 🔵 Blue: 25-50% margin (Medium Profit)
   - 🟠 Orange: <25% margin (Low Profit)

---

## Stock Transfer

### Creating a Transfer

1. Go to **Stock Transfer** → **+ New Transfer**
2. Fill in details:
   - **From Location**: Source location
   - **To Location**: Destination location
   - **Transfer Date**: Default is today
   - **Reference No**: Auto-generated

3. Add Items:
   - Select items to transfer
   - Enter quantities
   - Click **Add**

4. Click **Save Transfer**

### Transfer Approval

1. Go to **Stock Transfer** → **Pending**
2. Review transfer request
3. Click **Approve**
4. Stock is moved between locations

---

## Wastage & Returns

### Recording Wastage

1. Go to **Wastage** → **+ New Record**
2. Select **Type**: Wastage or Return
3. Fill in details:
   - **Date**: When wastage occurred
   - **Reason**: Expired, Damaged, Spoiled, etc.

4. Add Items:
   - Select wastage items
   - Enter quantities
   - Click **Add**

5. Click **Save**

### Wastage Analysis

View wastage patterns:
1. Go to **Reports** → **Wastage Report**
2. Filter by:
   - Date Range
   - Type (Wastage/Return)
   - Reason
3. View analysis by reason

---

## Reports

HIMS provides 6 comprehensive reports with PDF export:

### 1. Stock Summary Report

**What it shows:**
- Current stock levels
- Stock values
- Low stock items
- Location-wise breakdown

**How to generate:**
1. Go to **Reports** → **Stock Summary**
2. Select filters (Category, Location)
3. Click **Export to PDF** for printout

### 2. Purchase Report

**What it shows:**
- All purchases in date range
- Supplier-wise breakdown
- Payment mode analysis
- Total purchases, paid, credit

**Filters:**
- Date Range
- Supplier
- Payment Mode
- Status

### 3. Issue Report

**What it shows:**
- Department consumption
- Issue transactions
- Approved vs pending issues
- Department-wise breakdown

**Filters:**
- Date Range
- Department
- Issued By
- Status

### 4. Wastage Report

**What it shows:**
- Wastage and returns
- Reason-wise analysis
- Wastage value
- Type breakdown

**Filters:**
- Date Range
- Type (Wastage/Return)
- Reason

### 5. Recipe Costing Report

**What it shows:**
- All recipes with costs
- Profit margins
- High/medium/low profit items
- Menu engineering analysis

**Filters:**
- Category
- Minimum/Maximum Margin

### 6. Supplier Ledger Report

**What it shows:**
- Supplier-wise transactions
- Total purchases per supplier
- Credit purchases
- Outstanding balances

**Filters:**
- Date Range
- Supplier

### Exporting Reports

1. Open any report
2. Apply desired filters
3. Click **Download PDF** icon (top-right)
4. PDF is saved to device
5. Success message shows file path

---

## Settings

### General Settings

Configure company information:
- Hotel/Restaurant Name
- Full Address
- Contact Phone
- Email Address
- GST Number

### Report Settings

Configure automatic report generation (Coming Soon):
- Daily Stock Summary
- Weekly Purchase Report
- Monthly Summary

### Theme Settings

Choose appearance:
- **Light Mode**: Bright theme
- **Dark Mode**: Dark theme
- **System Default**: Follow device theme

### Notification Settings

Control alerts:
- **Low Stock Alerts**: Notify when stock below minimum
- **Pending Approvals**: Alert for pending transactions
- **Daily Summary**: Daily inventory summary (9 AM)

### Backup Settings

Configure automatic backups:
- **Enable Auto Backup**: Turn on/off
- **Backup Frequency**: Daily, Weekly, or Monthly
- **Manual Backup**: "Backup Now" button
- **View Backups**: See all backups with dates

---

## Backup & Restore

### Creating a Backup

**Manual Backup:**
1. Go to **Settings** → **Backup**
2. Click **Backup Now**
3. Wait for "Backup completed" message
4. Backup is saved as ZIP file

**Auto Backup:**
- Automatically runs on app startup
- Checks if backup is due based on frequency
- Creates backup in background
- Non-blocking (doesn't delay app start)

### Backup Location

Backups are stored in:
```
/Documents/HIMS_Backups/
HIMS_Backup_YYYYMMDD_HHMMSS.zip
```

### Viewing Backups

1. Go to **Settings** → **Backup**
2. Click **View Backups**
3. See all backups with:
   - File name
   - Date created
   - File size

### Restoring a Backup

⚠️ **Warning**: Restoring replaces all current data!

1. Click **View Backups**
2. Select a backup
3. Click **⋮** (menu) → **Restore**
4. Read warning carefully
5. Confirm restoration
6. Current database is backed up first
7. Selected backup is restored
8. **Restart app** for changes to take effect

### Deleting Backups

1. Click **View Backups**
2. Select a backup
3. Click **⋮** (menu) → **Delete**
4. Confirm deletion

### Backup Retention

- System keeps **last 7 backups**
- Older backups are **automatically deleted**
- Manual backups follow same rule

---

## Troubleshooting

### Low Stock Notifications Not Working

**Check:**
1. Go to **Settings** → **Notifications**
2. Ensure **Low Stock Alerts** is enabled
3. Check if items are actually below minimum stock
4. Restart app to trigger notification check

### Backup Failed

**Possible Causes:**
- Insufficient storage space
- Permission issues

**Solutions:**
1. Free up device storage
2. Check app has storage permissions
3. Try manual backup instead of auto

### PDF Not Exporting

**Check:**
1. Ensure storage permissions are granted
2. Free up device storage
3. Check if file is actually created (view backups folder)

### Data Not Syncing (Future Feature)

Currently, HIMS is offline-only. Cloud sync is planned for future release.

### App Crashes on Startup

**Solutions:**
1. Clear app cache
2. Restart device
3. Reinstall app (data is preserved in database file)
4. Restore from recent backup

### Stock Not Updating After Purchase

**Check:**
1. Is purchase **Approved**?
   - Only approved purchases update stock
2. Go to **Purchases** → find the purchase
3. Check status
4. Approve if pending

### Can't Delete an Item

**Possible Reasons:**
- Item has transactions (purchases, issues)
- Item is used in recipes
- Item has stock balance

**Solution:**
- Mark item as **Inactive** instead of deleting
- This hides it from lists but preserves data

---

## Best Practices

### Daily Operations

1. **Morning Routine:**
   - Check low stock items
   - Review pending approvals
   - Plan purchases

2. **Recording Transactions:**
   - Enter purchases immediately upon receiving
   - Record issues as they happen
   - Don't batch transactions

3. **End of Day:**
   - Approve all pending transactions
   - Review daily issue report
   - Check stock levels

### Weekly Tasks

1. **Stock Verification:**
   - Do physical stock count
   - Adjust discrepancies
   - Record wastage

2. **Report Review:**
   - Check purchase report
   - Analyze wastage report
   - Review supplier ledger

3. **Supplier Management:**
   - Update credit balances
   - Record payments
   - Check pending orders

### Monthly Tasks

1. **Comprehensive Review:**
   - Generate all reports
   - Analyze trends
   - Review recipe costs

2. **Maintenance:**
   - Verify backups exist
   - Clean up old transactions (if needed)
   - Update master data

3. **Planning:**
   - Adjust minimum stock levels
   - Review supplier performance
   - Update recipes

---

## Keyboard Shortcuts (Web)

| Shortcut | Action |
|----------|--------|
| `Ctrl + N` | New transaction (context-dependent) |
| `Ctrl + S` | Save current form |
| `Ctrl + F` | Focus search field |
| `Ctrl + P` | Export to PDF |
| `Esc` | Close dialog/cancel |

---

## Support & Contact

For technical support or feature requests:
- Email: support@hims.example.com
- Documentation: /docs folder in installation
- Version: Check **Settings** → **About**

---

## Glossary

| Term | Definition |
|------|------------|
| **FIFO** | First-In-First-Out (inventory valuation method) |
| **SKU** | Stock Keeping Unit (unique item identifier) |
| **Reorder Level** | Stock level that triggers reordering |
| **Lead Time** | Time between ordering and receiving stock |
| **COGS** | Cost of Goods Sold |
| **Gross Margin** | (Revenue - COGS) / Revenue |
| **Dead Stock** | Items not moving (zero consumption) |
| **PAR Level** | Periodic Automatic Replacement level |

---

## Version History

### v1.1.0 (Current)
- ✅ PDF Export for all 6 reports
- ✅ Automated backup system
- ✅ Low stock notifications
- ✅ Comprehensive error handling
- ✅ Settings panel with 5 tabs

### v1.0.0 (Initial Release)
- Basic inventory management
- Purchase & issue tracking
- Recipe management
- Stock transfer
- Core reports

---

**Document Version:** 1.1.0
**Last Updated:** January 2025
**Created by:** HIMS Development Team

---

For the latest updates and documentation, please visit the project repository.
