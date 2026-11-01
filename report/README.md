# PulseShare Project Report Deliverables

This folder contains the complete academic project report for the **PulseShare** application, prepared in strict accordance with the **Department of Information Technology** project report guidelines.

---

## 📁 Included Files

1. **[`pulseshare_report.tex`](pulseshare_report.tex)**  
   The primary, production-ready LaTeX source file designed for direct compilation on [Overleaf](https://www.overleaf.com) or local TeX engines. It includes all university-prescribed geometry, Times New Roman 12pt fonts, 1.5 line spacing, Roman/Arabic page numbering schemes, TikZ architecture diagrams, pgfplots benchmark charts, academic tables, and formatted source code appendices.

2. **[`pulseshare_report.md`](pulseshare_report.md)**  
   A parallel, fully detailed Markdown version containing equivalent chapters, GitHub-flavored markdown tables, Mermaid diagrams, and code snippets for offline viewing or Pandoc rendering.

---

## 🚀 How to Compile on Overleaf

1. Go to **[Overleaf](https://www.overleaf.com)** and create a new, blank project (e.g., named `PulseShare_Project_Report`).
2. Open `pulseshare_report.tex` from this directory, copy its entire contents, and paste it into the `main.tex` editor on Overleaf (or simply upload `pulseshare_report.tex` as your main file).
3. Ensure the compiler is set to **pdfLaTeX** (default on Overleaf).
4. Click **Recompile**. The generated PDF will be ~48–50 pages, perfectly meeting your target length!

---

## 📝 Placeholders to Customize Before Final Printing

All personalized variables are conveniently configured at the top of [`pulseshare_report.tex`](pulseshare_report.tex) (Lines 106–122) using standard LaTeX commands:

| Command in LaTeX | Line Number | Default / Placeholder Value | Action Needed |
| :--- | :--- | :--- | :--- |
| `\studentName` | Line 108 | `[STUDENT NAME]` | Replace with your full name |
| `\studentRoll` | Line 109 | `[00000000000]` | Replace with your university roll number |
| `\degreeName` | Line 110 | `Bachelor of Technology in Information Technology` | Change to Computer Science if applicable |
| `\departmentName` | Line 111 | `Department of Information Technology` | Change to Computer Science & Engg if applicable |
| `\instituteName` | Line 112 | `Guru Tegh Bahadur Institute of Technology` | Update if needed |
| `\universityName` | Line 113 | `Guru Gobind Singh Indraprastha University` | Update if needed |
| `\academicYear` | Line 115 | `2022--2026` | Adjust your batch year |
| `\internalGuide` | Line 116 | `[INTERNAL GUIDE NAME]` | Replace with your college supervisor's name |
| `\hodName` | Line 118 | `[HOD NAME]` | Replace with your Department Head's name |
| `\companyName` | Line 120 | `[TRAINING ORGANIZATION / INNOVATION LAB]` | Replace with company name (if industrial training) |
| `\mentorName` | Line 121 | `[EXTERNAL MENTOR / INDUSTRY SUPERVISOR]` | Replace with industry mentor's name |
| `\trainingDuration` | Line 122 | `[23rd June, 2026 -- 14th August, 2026]` | Adjust your internship / project dates |
| **Certificate Xerox** | Lines 260–280 | Bounding box placeholder | In Overleaf, replace the `\fbox{...}` block with `\includegraphics[width=0.9\textwidth]{your_cert.png}` once you scan your certificate |

---

## 📋 Compliance with Departmental Guidelines

The report strictly mirrors the **14-point institutional project guidelines**:
1. **Title Page**: Included (`\begin{titlepage}`) with 22pt bold centered title.
2. **Certificate**: Sign-off certificate for internal guide & HOD + visual bounding box for company Xerox certificate.
3. **Abstract**: Comprehensive summary (<600 words) highlighting the AI fallback and performance.
4. **Table of Contents**: Auto-generated `\tableofcontents`.
5. **List of Tables**: Auto-generated `\listoftables`.
6. **List of Figures**: Auto-generated `\listoffigures`.
7. **Introduction** (Chapter 1): Background, Motivation, Objectives, Scope, Methodology.
8. **Requirement Analysis (SRS)** (Chapter 2): Complete IEEE 830-style specification with Hardware/Software specs, Functional Requirements matrix (FR-01 to FR-12), Non-Functional Requirements, and TikZ Use Case Diagram with detailed UC-01 specification.
9. **System Design (Client-Server Architecture, ER Diagram, DFD)** (Chapter 3): Distributed Client-Server architecture diagram, formal Entity-Relationship (ER) diagram, DFD Level 0 (Context Diagram), DFD Level 1 (Process Decomposition Diagram), and state/sequence models.
10. **Body of Thesis (Additional Chapters)**:
    - Chapter 4: Technology Stack and Tools
    - Chapter 5: Module-Wise Implementation Details (with listings)
    - Chapter 6: Application Evolution and Defect Refactoring
    - Chapter 7: Technical Challenges and Solutions
11. **Results** (Chapter 8): Unit testing results (10/10 passing), physical device checks, and empirical `pgfplots` latency & accuracy bar charts.
12. **Summary and Conclusions** (Chapter 9): Achievements, Technical Learning Outcomes, Future Scope, and Conclusion.
13. **References**: Standard IEEE format citations.
14. **Appendix**: Configuration files, core engine source excerpts, and test suite listings.

- **Page Margins**: Left: 3.5 cm, Right: 3.0 cm, Top: 2.54 cm (1 inch), Bottom: 2.54 cm (1 inch).
- **Typography**: Times New Roman font (`mathptmx`), 12 pt body size, 1.5 line spacing (`\onehalfspacing`), justified alignment.
- **Captions**: Table captions placed **above** tables; figure/diagram captions placed **below** figures.
