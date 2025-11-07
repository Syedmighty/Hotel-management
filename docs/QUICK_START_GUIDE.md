# HIMS Quick Start Guide

**Get started with Hotel Inventory Management System in 15 minutes!**

---

## 📋 What You'll Learn

1. Initial setup (5 minutes)
2. Adding your first items (3 minutes)
3. Recording a purchase (4 minutes)
4. Creating an issue (3 minutes)

---

## 🚀 Step 1: Initial Setup (5 minutes)

### Configure Company Details

1. Open HIMS
2. Click **Settings** (⚙️ icon in sidebar)
3. Go to **General** tab
4. Fill in your details:
   ```
   Hotel Name: Grand Palace Hotel
   Address: 123 Main Street, City
   Phone: +1-555-1234
   Email: info@grandpalace.com
   GST: 29XXXXX1234X1ZX
   ```
5. Click **Save Company Information**

### Set Up Notifications

1. Stay in **Settings**
2. Go to **Notifications** tab
3. Enable:
   - ✅ Low Stock Alerts
   - ✅ Pending Approvals
   - ⬜ Daily Summary (optional)

### Configure Backups

1. Go to **Backup** tab
2. Enable **Auto Backup**
3. Set frequency to **Daily**
4. Click **Backup Now** to create first backup

✅ **Setup Complete!**

---

## 🏷️ Step 2: Add Your First Items (3 minutes)

### Add a Category

1. Go to **Inventory** → **Categories**
2. Click **+ Add Category**
3. Enter: `Vegetables`
4. Click **Save**

Repeat for: `Dairy`, `Spices`, `Beverages`

### Add Storage Locations

1. Go to **Inventory** → **Locations**
2. Add these locations:
   - `Main Kitchen`
   - `Dry Store`
   - `Cold Storage`
   - `Bar`

### Add Stock Items

**Example 1: Tomatoes**
1. Go to **Inventory** → **Stock Items**
2. Click **+ Add Item**
3. Fill in:
   ```
   Item Name: Tomatoes
   Category: Vegetables
   Location: Main Kitchen
   Unit: kg
   Minimum Stock: 5
   Maximum Stock: 50
   Reorder Level: 10
   ```
4. Click **Save**

**Example 2: Milk**
```
Item Name: Fresh Milk
Category: Dairy
Location: Cold Storage
Unit: L
Minimum Stock: 10
Maximum Stock: 100
Reorder Level: 20
```

**Example 3: Olive Oil**
```
Item Name: Olive Oil
Category: Cooking Oil
Location: Dry Store
Unit: L
Minimum Stock: 2
Maximum Stock: 20
Reorder Level: 5
```

✅ **Your inventory is ready!**

---

## 🛒 Step 3: Record Your First Purchase (4 minutes)

### Add a Supplier First

1. Go to **Suppliers** → **+ Add Supplier**
2. Fill in:
   ```
   Name: Fresh Farms Suppliers
   Contact: John Doe
   Phone: +1-555-5678
   Email: john@freshfarms.com
   Address: 456 Market Road
   GST: 29YYYY5678Y1ZY
   ```
3. Click **Save**

### Create a Purchase

1. Go to **Purchases** → **+ New Purchase**
2. Fill in purchase details:
   ```
   Supplier: Fresh Farms Suppliers
   Purchase Date: (Today's date)
   Invoice Number: FF-2025-001
   Payment Mode: Credit
   Status: Pending
   ```

3. Add Items:
   - Click **+ Add Item**
   - Select **Tomatoes**
   - Quantity: `20`
   - Rate: `50` (₹50 per kg)
   - Click **Add to Purchase**

   - Click **+ Add Item** again
   - Select **Fresh Milk**
   - Quantity: `30`
   - Rate: `60` (₹60 per L)
   - Click **Add to Purchase**

4. Review totals:
   ```
   Tomatoes: 20 kg × ₹50 = ₹1,000
   Milk: 30 L × ₹60 = ₹1,800
   ─────────────────────────────
   Total: ₹2,800
   ```

5. Click **Save Purchase**

### Approve the Purchase

1. Go to **Purchases** → **Pending**
2. Click on your purchase (FF-2025-001)
3. Review the details
4. Click **Approve**
5. ✅ Stock is now updated!

**Verify Stock Update:**
1. Go to **Inventory** → **Stock Items**
2. Check:
   - Tomatoes: Now shows 20 kg
   - Fresh Milk: Now shows 30 L

---

## 📤 Step 4: Create Your First Issue (3 minutes)

### Issue Items to Kitchen

1. Go to **Issues** → **+ New Issue**
2. Fill in:
   ```
   Department: Kitchen
   Issue Date: (Today's date)
   Issued By: Your Name
   Purpose: Daily Cooking
   ```

3. Add Items:
   - Click **+ Add Item**
   - Select **Tomatoes**
   - Quantity: `5`
   - Rate: Auto-filled (₹50)
   - Click **Add**

   - Click **+ Add Item**
   - Select **Olive Oil**
   - Quantity: `2`
   - Rate: Auto-filled
   - Click **Add**

4. Review total
5. Click **Save Issue**

### Approve the Issue

1. Go to **Issues** → **Pending**
2. Click on your issue
3. Review items
4. Click **Approve**
5. ✅ Stock is deducted!

**Verify Stock Update:**
- Tomatoes: 20 kg → 15 kg
- Olive Oil: (previous stock) → (previous - 2) L

---

## 📊 Step 5: View Your First Report (2 minutes)

1. Go to **Reports** → **Stock Summary**
2. See all your items with current stock
3. Click **📥 Export to PDF** (top-right)
4. PDF is saved!
5. Open it to see professional report

---

## 🎯 What's Next?

### Explore More Features

1. **Recipe Management**
   - Create recipes
   - Calculate costs
   - Analyze profit margins

2. **Stock Transfer**
   - Move items between locations
   - Track inter-location movement

3. **Wastage Tracking**
   - Record spoilage
   - Track returns
   - Analyze wastage patterns

4. **Advanced Reports**
   - Purchase Report
   - Issue Report
   - Wastage Report
   - Recipe Costing Report
   - Supplier Ledger

### Set Up Daily Routine

**Morning (5 minutes):**
- Check Dashboard
- Review low stock alerts
- Approve pending transactions

**As Transactions Happen:**
- Record purchases immediately
- Issue items as needed
- Transfer stock between locations

**Evening (5 minutes):**
- Approve remaining pending items
- Check today's consumption
- Plan tomorrow's purchases

---

## 💡 Pro Tips

### Inventory Management

1. **Set Realistic Min/Max Levels**
   - Based on consumption patterns
   - Consider lead times
   - Account for peak periods

2. **Use Reorder Levels**
   - Set 20-30% above minimum
   - Prevents stockouts
   - Maintains buffer stock

3. **Regular Stock Counts**
   - Weekly for high-value items
   - Monthly for all items
   - Adjust discrepancies promptly

### Purchase Management

1. **Always Use Credit Mode for Suppliers**
   - Tracks outstanding balances
   - Generates supplier ledger
   - Better payment tracking

2. **Enter Invoice Numbers**
   - Easy reconciliation
   - Audit trail
   - Supplier queries

3. **Approve Quickly**
   - Stock updates immediately
   - Prevents duplicate entries
   - Maintains real-time data

### Issue Management

1. **Department-Wise Issues**
   - Track consumption by area
   - Identify high users
   - Control costs

2. **Add Purpose Notes**
   - "Daily Cooking"
   - "Banquet - Wedding Party"
   - "Catering - Corporate Event"
   - Better reporting

### Backup Management

1. **Verify Backups Weekly**
   - Check last backup date
   - Ensure auto-backup is working
   - Test restore once a month

2. **Keep External Copies**
   - Copy backup files to USB
   - Store off-site
   - Cloud backup (future)

---

## 🆘 Common Questions

### Q: Can I delete a wrong entry?

**A:** It depends:
- **Before Approval**: Yes, you can delete or edit
- **After Approval**: No, to maintain audit trail
  - Create reverse entry instead
  - Or adjust stock with reason

### Q: How do I handle returns to supplier?

**A:**
1. Go to **Wastage** → **+ New Record**
2. Select Type: **Return**
3. Add returned items
4. Reason: "Return to Supplier"

### Q: Stock shows negative?

**A:** This happens when:
- Issues were approved before purchases
- Stock adjustment was negative
- Check transaction history to trace

### Q: How to export data to Excel?

**A:** Currently:
- Export PDF reports
- PDF can be converted to Excel
- Native Excel export: Coming Soon

### Q: Can multiple users access simultaneously?

**A:** Current version:
- Single-user per device
- Multi-user sync: Future feature
- For now: One manager handles entries

---

## 📱 Mobile vs Web

### Mobile App
- ✅ Touch-friendly interface
- ✅ Barcode scanning
- ✅ On-the-go access
- ✅ Push notifications

### Web Version
- ✅ Larger screen
- ✅ Faster data entry
- ✅ Side-by-side views
- ✅ Better for reports

**Recommendation**: Use both!
- Mobile for quick entries and alerts
- Web for reports and bulk data entry

---

## 🎓 Training Checklist

Use this to track your team training:

- [ ] Basic navigation
- [ ] Adding stock items
- [ ] Recording purchases
- [ ] Creating issues
- [ ] Approving transactions
- [ ] Stock transfers
- [ ] Wastage recording
- [ ] Generating reports
- [ ] PDF exports
- [ ] Backup & restore
- [ ] Settings configuration
- [ ] Troubleshooting basics

---

## ✅ You're Ready!

Congratulations! You've completed the quick start guide.

You now know how to:
- ✅ Set up the system
- ✅ Add inventory items
- ✅ Record purchases
- ✅ Create issues
- ✅ Generate reports

**Next Steps:**
1. Read the full [User Manual](./USER_MANUAL.md)
2. Explore all features
3. Set up your complete inventory
4. Train your team

---

**Need Help?**

- 📖 Full Manual: `USER_MANUAL.md`
- 🐛 Issues: GitHub Issues
- 📧 Support: support@hims.example.com

**Happy Inventory Management! 🎉**

---

**Document Version:** 1.1.0
**Last Updated:** January 2025
