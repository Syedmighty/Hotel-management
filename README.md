# Hotel Inventory Management System (HIMS)

A comprehensive, offline-first hotel inventory management system built with Flutter for web and mobile platforms.

## 🎯 Features

### Core Functionality
- **Product Management**: Complete CRUD operations with barcode support
- **Supplier Management**: Track suppliers with GST details and outstanding balances
- **Purchase Entry (GRN)**: Record goods received from suppliers with line items
- **Issue Vouchers**: Issue materials to kitchen/departments with stock deduction
- **Wastage & Returns**: Record wastage and supplier returns
- **Stock Adjustments**: Manual stock corrections with approval workflow
- **Stock Transfers**: Transfer inventory between departments/locations
- **Physical Stock Audits**: Verify actual vs system stock

### Advanced Features
- **Recipe Management**: Define recipes and auto-calculate menu costs
- **Offline-First**: Full functionality without internet connection
- **LAN Sync**: Automatic data synchronization across devices on local network
- **Multi-Printer Support**: A4 and thermal printer support
- **Excel Import/Export**: Bulk data operations
- **Automated Reports**: Schedule daily summaries via email/share
- **Role-Based Access**: Admin, Storekeeper, Chef, Accountant, Auditor roles
- **Barcode/QR Scanning**: Fast item identification and stock operations
- **Comprehensive Logging**: Track all operations for audit trail

## 🏗️ Architecture

### Technology Stack
- **Frontend**: Flutter 3.x (Web + Mobile PWA)
- **Database**: Drift (SQLite + IndexedDB)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Backend Server**: Node.js + Express (LAN only)
- **Sync Protocol**: REST JSON over HTTP

### Database Schema
24 comprehensive tables covering:
- Core inventory (Products, Suppliers)
- Transactions (Purchases, Issues, Wastage) with normalized line items
- Stock management (Adjustments, Transfers, Physical Counts)
- Recipe management for menu costing
- User authentication and authorization
- Complete audit logs (Sync, Print, Import, Auth, System)

## 📋 Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Node.js 16+ (for backend server)
- Android Studio / Xcode (for mobile development)
- Chrome / Edge (for web development)

## 🚀 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/hotel-inventory-management.git
cd hotel-inventory-management
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Generate Code (Drift, Riverpod)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the App

**Web:**
```bash
flutter run -d chrome
```

**Mobile (Android):**
```bash
flutter run -d android
```

**Mobile (iOS):**
```bash
flutter run -d ios
```

## 🗄️ Database

The app uses Drift for local database management. The schema includes:

- **Products**: SKU, pricing, stock levels, batch tracking
- **Suppliers**: Contact info, GST details, balances
- **Transactions**: Normalized purchase/issue/wastage records
- **Stock Operations**: Adjustments, transfers, physical counts
- **Recipes**: Menu items with ingredient lists and costing
- **Audit Logs**: Comprehensive tracking of all operations

## 🔐 Authentication

Default credentials:
- Username: `admin`
- Password: `admin123`

**⚠️ Important**: Change the default password on first login.

### User Roles
- **Admin**: Full system access
- **Storekeeper**: Manage purchases, issues, stock
- **Chef**: View recipes, create issues
- **Accountant**: View reports, transactions
- **Auditor**: Read-only access to all data

## 📱 Responsive Design

The app is fully responsive and works on:
- Desktop (1920x1080+)
- Tablet (768x1024)
- Mobile (375x667+)
- Web browsers (Chrome, Firefox, Safari, Edge)

## 🔄 Sync & Backup

### LAN Sync
- Automatic conflict resolution using timestamps
- Batch sync in chunks of 100 records
- Retry mechanism with exponential backoff
- Conflict logging for manual resolution

### Backup
- Daily incremental backups
- Weekly full backups
- Cloud backup option (configurable)

## 📊 Reports

Available reports:
1. Stock Summary Report
2. Purchase Report
3. Issue Report
4. Wastage Report
5. Recipe Costing Report
6. Supplier Ledger
7. Stock Movement Report
8. Audit Trail Report

All reports support:
- PDF export (A4 format)
- Excel export
- Date range filtering
- Email/share functionality

## 🖨️ Printing

### Supported Printers
- **A4 Printers**: Standard office printers via PDF
- **Thermal Printers**: 80mm receipt printers via Bluetooth/USB

### Print Templates
Customizable JSON templates for:
- Purchase Entry (GRN)
- Issue Vouchers
- Wastage Records
- Stock Reports

### Multi-Copy Support
Print multiple copies with labels:
- Store Copy
- Manager Copy
- Supplier Copy
- Department Copy

## 🔧 Configuration

### System Settings
Navigate to Settings to configure:
- Hotel information
- Stock valuation method (FIFO/LIFO/Weighted Average)
- LAN server URL
- Backup schedule
- User management
- Printer configuration

## 📱 Barcode Scanning

Scan barcodes for:
- Quick product lookup
- Fast purchase receiving
- Issue voucher creation
- Physical stock counts

Supports standard barcode formats: EAN-13, UPC-A, Code 128, QR codes

## 🧪 Testing

Run tests:
```bash
flutter test
```

## 📦 Building for Production

### Web (PWA)
```bash
flutter build web --release
```

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🛠️ Development Roadmap

### Phase 1 - Core MVP ✅
- Products, Suppliers CRUD
- Purchase Entry (GRN)
- Issue Vouchers
- Basic Stock Reports
- Offline storage with Drift
- User authentication

### Phase 2 - Advanced Features (In Progress)
- Wastage & Returns
- Stock Audit/Physical Count
- Excel Import/Export
- PDF Reports
- Barcode scanning

### Phase 3 - Automation & Polish
- Auto reports
- Advanced sync with conflict resolution
- Printing subsystem
- Recipe management
- Menu costing

### Phase 4 - Multi-branch
- Cloud aggregator
- Multi-hotel dashboard
- Centralized reporting

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Email: support@example.com

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Drift team for the excellent database solution
- Riverpod team for state management
- All open-source contributors

---

**Built with ❤️ for the hospitality industry**
