# UNI bot - Your AI-Powered Course Assistant

## What is UNI Bot?
UNI Bot is an AI-powered assistant designed to enhance learning outcome and experience for both educators and students. 
UNI Bot provides intelligent support, analytics, and automation to improve course engagement, streamline administrative tasks, and personalize learning paths.

## Why Install UNI Bot?
Educators and learners benefit from UNI Bot’s cutting-edge AI capabilities, making teaching and studying more efficient and engaging. Key reasons to install UNI Bot include:
- **Effortless AI Integration** – Get up and running in just 10 minutes with our automated installation script.
- **Highly Customizable** – Adjust colors, widget sizes, and pipelines to match your platform’s needs.
- **Advanced AI Support** – Utilize over 10+ Large Language Models (LLMs) with configurable prompts and context management.
- **Scalable & Secure** – Deploy on-premises or in the cloud, ensuring enterprise-grade security and accessibility.
- **Actionable Insights** – Receive real-time analytics to improve course content and student performance.
- **Comprehensive Helpdesk** – Automate student support with ticketing and internal knowledge bases.

## What You Get After Installation

### **For Teachers: Meet UNI Bot – Your AI-Powered Course Assistant!**

**Empower Your Teaching with UNI Bot Today!**
- **Quick & Easy Setup** – Install in just 10 minutes with a single automated script.
- **Fully Customizable** – Modify widget appearance, colors, and pipeline structures.
- **AI-Powered Support** – Leverage 10+ LLMs with configurable prompts and context size adjustments.
- **Enterprise-Grade Security** – Choose between cloud-based or on-premises deployment for maximum security and scalability.
- **In-Depth Course Insights** – Identify areas for improvement with automated analytics and reporting.
- **Internal Knowledge Base** – Manage an FAQ system for instant access to relevant information.
- **Automated Helpdesk** – Provide student support through an embedded helpdesk with ticketing functionality.
- **Real-Time Analytics** – Get daily reports on system usage and student engagement.

**Boost Student Engagement & Success**
- **Tailored Student Support** – UNI Bot adapts to every student’s learning needs.
- **Embedded Helpdesk** – Ensure seamless communication and problem resolution.
- **Learning Analytics** – Improve and personalize student learning experiences.

**Prepare Students for Their Future**
- **VORKIS Integration** – Provide real-time job market insights and career path recommendations.

**Empower Your Teaching with UNI Bot Today!**  
[Explore UNI Bot for Educators](https://www.intela-bot.com/)
---

### **For Students: Meet UNI Bot – Your AI-Powered Learning Coach & Career Assistant!**

**UNI Bot is your personal AI learning assistant, making studying easier, faster, and more engaging.**  
Whether you're preparing for exams, mastering a new skill, or exploring career opportunities, UNI Bot has your back!

**Why You’ll Love UNI Bot**
- **Instant Summaries** – Get quick, clear summaries of your lessons.
- **Flexible Content Format** – Convert lessons into visual guides, bullet points, or deep explanations.
- **Adaptive Learning** – Request extra quizzes, exercises, and practice tests.
- **Career Insights** – Discover real-world job applications for your skills.

**Need Help? UNI Bot Has You Covered!**
- **Smart Tech Support** – Resolve course-related technical issues instantly.
- **Troubleshooting & Ticketing** – Submit support tickets directly through UNI Bot.
- **Teacher Hotline Support** – Enable direct email-based assistance when needed.

**Boost Your Career with UNI Bot & VORKIS**
- **Real-Time Job Market Insights** – Stay updated on industry trends and career paths.
- **Accelerated Career Growth** – Get the skills needed for your dream job.
- **Confidence in Upskilling** – Whether you're learning, job-hunting, or switching careers, UNI Bot is here to guide you.

**Ready to take your learning to the next level? Start with UNI Bot today!**  
[Explore UNI Bot Now](https://www.intela-bot.com/)

## Manual installation for existing platform

- Clone this repo into the `plugins` folder in the project root.
- Switch to the virtual environment where Tutor==18.1.3 is installed.
- Set `TUTOR_PLUGINS_ROOT` environment variable:
  ```bash
  export TUTOR_PLUGINS_ROOT=${PROJECT_ROOT}/plugins
  ```
- Install the plugin as follows:
  ```bash
  pip install -e ${PROJECT_ROOT}/plugins/${PLUGIN_FOLDER_NAME}/
  ```
- Run:
  ```bash
  tutor plugins enable unibot
  tutor images build openedx
  tutor images build mfe
  tutor local launch
  ```
- Start Edx using Tutor.

## Configuration

The plugin takes values from the Tutor-related `config.yml` file for remote configuration, Django settings overriding, etc. If a specific value is missing in the config file, the default values are used from the `config` dictionary inside `tutor_unibot.plugin`.

# UniBot Plugin Installation Script for Open edX

This script automates the installation and configuration of UniBot on an Open edX instance. It handles all necessary setup steps, including plugin installation, OAuth configuration, and tenant registration.

## Prerequisites

The script requires the following tools to be installed and properly configured:

- git
- tutor==18.1.3
- docker
- pip
- openssl

Docker must be running, and the current user must have proper permissions (be in the docker group).

## Installation

1. Download the installation script:
   ```bash
   wget https://raw.githubusercontent.com/intela-bot/tutor-unibot/main/unibot_install.sh && chmod +x unibot_install.sh
   ```

2. Run the script with your UniBot API key:
   ```bash
   ./unibot_install.sh -unibotapikey YOUR_API_KEY
   ```
