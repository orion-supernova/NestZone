// Convex Auth provider config. On self-hosted Convex, CONVEX_SITE_URL is set
// automatically by the backend container (here: https://nestzone-convex-api.walhallaa.com).
export default {
  providers: [
    {
      domain: process.env.CONVEX_SITE_URL,
      applicationID: "convex",
    },
  ],
};
