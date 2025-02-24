# UNIbot Plugin for Open edX

This guide explains how to install and configure the UNIbot plugin for Open edX.

## Prerequisites

- Python virtual environment
- Access to Open edX admin interface
- Tutor installation rights

## 1. Environment Setup

### Create and Activate Virtual Environment

```bash
python -m venv venv

# Windows
source venv/Scripts/activate

# Linux/MacOS
source venv/bin/activate
```

### Install Tutor

```bash
pip install tutor[full]
```

## 2. UNIbot Plugin Installation

1. Create and navigate to plugins directory:

```bash
mkdir plugins && cd plugins
```

2. Clone the plugin repository:

```bash
git clone https://git.intela.dev/open-source/uni-bot-on-open-edx/tutor-unibot.git
```

3. Install the plugin:

```bash
pip install -e /path/to/plugins-folder/tutor-unibot
```

4. Verify installation:

```bash
tutor plugins list
```

![Plugin List](./images/1.png)

5. Enable the plugin:

```bash
tutor plugins enable unibot
```

After enabling, you should see a green checkmark next to "unibot" in the plugins list:
![Enabled Plugin](./images/2.png)

6. Build required images:

```bash
tutor images build openedx && tutor images build mfe
```

7. (Optional) Launch local environment:

```bash
tutor local launch
```

## 3. OAuth Configuration

### Enable API Access

1. Navigate to `<LMS_URL>/admin/api_admin/apiaccessconfig/`
2. Click "Add API Access Config"
3. Enable the configuration and save
   ![API Access Config](./images/4.png)

### Generate API Credentials

1. Go to `<LMS_URL>/api-admin/` and submit an access request
   ![API Access Request](./images/3.png)

2. Approve the request:

   - Navigate to `<LMS_URL>/admin/api_admin/apiaccessrequest/`
   - Change status from "Pending" to "Approved"
     ![Approve Request](./images/5.png)

3. Obtain credentials:
   - Visit `<LMS_URL>/api-admin/status/`
   - Create a new token
     ![API Credentials](./images/2-1.jpg)
   - Save the provided API Client ID and Secret
     ![API Credentials](./images/7.jpg)

## 4. UNIbot Backend Registration

1. Access the UNIbot Meta-Admin application at https://unibot-sf.san.systems/meta-admin/
   ![Meta-Admin Login](./images/8.png)

2. Add new tenant:
   - Click "Add new tenant" in the top right corner
   - Fill in the form with your OAuth credentials
     ![New Tenant Form](./images/9.png)
   - Save and note the tenant credentials
     ![Tenant Credentials](./images/10.png)

## 5. Open edX Configuration

1. Configure UNIbot Settings:

   - Access Open edX LMS admin page
   - Navigate to UNIbot settings
     ![UNIbot Settings](./images/11.png)
   - Add new configuration
     ![Add Configuration](./images/12.png)
   - Enter Meta-Admin credentials and enable the configuration

2. Update Site Configuration:
   - Navigate to site configuration in LMS admin panel
     ![Site Configuration](./images/13.png)
   - Select the site without ports in the name
   - Add the following JSON configuration (replace `<BACKEND_URL>` with your actual backend URL):

```json
{
  "ENABLE_PROFILE_MICROFRONTEND": "true",
  "MFE_CONFIG_OVERRIDES": {
    "learning": {
      "EXTERNAL_SCRIPTS": [
        {
          "isAuthnRequired": true,
          "head": "",
          "body": {
            "top": "",
            "bottom": "<script src=\"<BACKEND_URL>/widget/loader.js\"></script>"
          }
        }
      ]
    }
  }
}
```

![Site Configuration Settings](./images/14.png)
