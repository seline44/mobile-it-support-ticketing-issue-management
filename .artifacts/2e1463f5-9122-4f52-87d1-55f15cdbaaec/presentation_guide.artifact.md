# TriageDesk — Comprehensive System Presentation Script & Panel Q&A

This guide covers the **entire TriageDesk system** (Frontend, Backend, Database, WhatsApp integration, Reporting, and Authentication) to ensure you are fully prepared for your panel presentation.

---

## 1. 5-Minute Comprehensive Presentation Script

### [0:00 - 0:45] 1. Executive Summary & Problem Statement
> *"Hello panel members. Today, I am presenting **TriageDesk**—an enterprise-grade, multi-channel IT support and ticketing ecosystem designed to streamline issue resolution between end-users, field technicians, and system administrators.*
>
> *Traditional support desks suffer from fragmented communication, lack of real-time visibility, and manual bottlenecks. TriageDesk solves this by integrating cross-platform clients, automated backend workflows, real-time data sync, and WhatsApp guest reporting into a single unified platform."*

### [0:45 - 1:30] 2. System Architecture & Tech Stack
> *"Let's review the end-to-end system architecture:*
> - **Frontend Client**: Built with **Flutter** (Material 3), delivering responsive experiences across Web, Android, iOS, and Desktop.
> - **Backend API**: Powered by **FastAPI (Python 3.13)**, featuring async request handling, dependency-injected security, and automated OpenAPI documentation.
> - **Database Layer**: Relational database powered by **PostgreSQL** using SQLAlchemy ORM, ensuring ACID compliance and relational integrity across users, tickets, notes, and audit logs."

### [1:30 - 2:30] 3. Core Modules & Key Workflows
> *"The system is structured around four robust operational modules:*
> 1. **Authentication & RBAC**: Features instant **Google Sign-In** (with desktop session auto-detection and secure account pickers) alongside traditional email login. The system automatically determines user roles (**Reporter**, **Technician**, **Administrator**) and enforces strict backend security.
> 2. **Ticket Lifecycle Engine**: Reporters can create categorized tickets with attachments. Technicians pick up, update, resolve, or re-open tickets with full audit trails and internal staff notes.
> 3. **Omnichannel WhatsApp Integration**: Supports incoming and outgoing WhatsApp webhooks (via Meta / Twilio APIs) enabling guests without app accounts to submit tickets and receive live status updates via messaging.
> 4. **Administrative Oversight & Reports**: Admins manage user approval statuses, lock/unlock accounts, and export comprehensive ticket analytics as PDF, Word (.docx), or Excel (.xlsx) reports."

### [2:30 - 3:15] 4. Advanced Technical Highlights
> *"To ensure enterprise reliability, we implemented several advanced engineering patterns:
> - **Real-Time Polling & Sync**: Dashboards automatically sync with the backend every 5 seconds, capturing updates from other devices and WhatsApp in real time without manual refreshes.
> - **Resilient Offline & Emulator Fallbacks**: Smart fallback layers prevent network disruptions or missing local server setups from breaking the user experience during testing or offline usage.
> - **Robust Automated Testing**: Covered by extensive unit and widget test suites verifying rendering, business logic, and PDF/Excel generation."*

### [3:15 - 3:45] 5. Conclusion
> *"TriageDesk represents a complete, production-ready solution for enterprise IT support. Thank you, and I look forward to your questions."*

---

## 2. Panel Q&A: Comprehensive System Questions & Answers

### Q1: "How is data modeled in PostgreSQL, and how do you handle relationships between users, tickets, and notes?"
**Answer:**
> *"We use SQLAlchemy ORM with PostgreSQL. The core models are structured relationally:
> - **User Table**: Stores credentials, role (`Reporter`, `Technician`, `Administrator`), `approval_status`, and active flags.
> - **Ticket Table**: Foreign-keyed to `reporter_id` and `assigned_technician_id`, storing category, status (`Open`, `In Progress`, `Resolved`, `Closed`), priority, and description.
> - **TicketNote Table**: Links internal or public notes to a ticket and an author (`author_id`), maintaining a complete discussion and resolution history."*

### Q2: "How does the WhatsApp webhook integration work alongside the web/mobile app?"
**Answer:**
> *"The FastAPI backend exposes webhook endpoints that receive incoming JSON payloads from WhatsApp providers (Meta Graph API / Twilio). When an incoming message arrives from a phone number:
> 1. The system checks if the phone number is mapped to an existing guest or WhatsApp contact.
> 2. If it's a new request, it automatically creates a ticket attributed to a guest/WhatsApp account.
> 3. Staff replies made in the web/mobile app trigger automated WhatsApp notification dispatches back to the reporter's phone, keeping both channels fully synchronized."*

### Q3: "Why did you choose 5-second polling instead of WebSockets for real-time updates?"
**Answer:**
> *"For an IT support ticketing system, 5-second polling provides an ideal balance of simplicity, reliability, and firewall-friendliness. Unlike WebSockets which require persistent TCP connections and complex heartbeat/reconnection logic across server restarts, HTTP polling over our stateless FastAPI backend is extremely robust, stateless, works seamlessly behind load balancers (like Render), and ensures dashboards stay synchronized with zero manual refresh."*

### Q4: "How do the administrative export reports (PDF, Word, Excel) work?"
**Answer:**
> *"Administrators can generate downloadable reports directly from the Reports tab. On the backend/frontend, we use specialized libraries (`pdf`, `excel`, `archive`) to compile filtered ticket datasets into formatted documents on-the-fly. The data is structured into professional tables with summaries, allowing management to audit resolution metrics instantly."*

### Q5: "How does authentication security work, particularly for Google Sign-In and passwords?"
**Answer:**
> *"We use **JWT (JSON Web Tokens)** signed with `HS256` and an environment-secured secret key. Password authentication uses `pwdlib` for secure password hashing. For Google Sign-In, the client securely resolves the desktop/Google email session, validates it against the backend, and provisions or logs in the user with an automatic 'Approved' status for verified Google emails, issuing a valid JWT access token for subsequent authorized API requests."*

---

### [!IMPORTANT] Final Presentation Checklist
- [ ] **Backend Running**: Keep your FastAPI server running (`python -m uvicorn main:app --reload`).
- [ ] **Database Connected**: Verify PostgreSQL is active and seeded (`python create_users.py`).
- [ ] **App Ready**: Have your Flutter app open on Chrome or your emulator.
- [ ] **Walkthrough Confidence**: Be ready to demo creating a ticket, viewing it on the technician dashboard, and exporting a report.
