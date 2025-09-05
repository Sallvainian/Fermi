# Legend: fn=function cl=class cn=constant m=methods p=properties

functions/lib/cleanup.js > 
  cn scheduler_1:unknown
  cn admin:unknown
  cn manualPKCECleanup:function
functions/lib/createTestStudent.js > 
  cn admin:unknown
  cn https_1:unknown
  cn db:unknown
functions/lib/customClaims.js > 
  cn https_1:unknown
  cn firestore_1:unknown
  cn v2_1:unknown
  cn admin:unknown
functions/lib/emailVerification.js > 
  fn sendEmailViaCloudflare(to:?,subject:?,html:?,text:?,workerUrl:?,apiKey:?):void async
  fn generateVerificationCode():void
  fn isEmailAlreadyUsed(email:?):void async
  fn checkRateLimit(email:?):void async
  cn admin:unknown
  cn https_1:unknown
  cn scheduler_1:unknown
  cn params_1:unknown
  cn cloudflareWorkerUrl:unknown
  cn cloudflareApiKey:unknown
  cn db:unknown
functions/lib/emailVerificationCloudflare.js > 
  fn sendEmailViaCloudflare(to:?,subject:?,html:?,text:?):void async
  fn generateVerificationCode():void
  fn isEmailAlreadyUsed(email:?):void async
  fn checkRateLimit(email:?):void async
  cn functions:unknown
  cn admin:unknown
  cn https_1:unknown
  cn scheduler_1:unknown
  cn db:unknown
  cn CLOUDFLARE_WORKER_URL:unknown
  cn CLOUDFLARE_API_KEY:unknown
functions/lib/index.js > functions/lib/cleanup,functions/lib/createTestStudent,functions/lib/customClaims,functions/lib/emailVerification,functions/lib/migrate-user-roles-cloud,functions/lib/oauth
  cn firebase_functions_1:unknown
  cn admin:unknown
functions/lib/migrate-user-roles-cloud.js > 
  cn admin:unknown
  cn v2_1:unknown
functions/lib/migrate-user-roles.js > 
  fn migrateUserRoles():void async
  cn admin:unknown
functions/lib/oauth.js > 
  fn fetchWithTimeout(url:?,options:?,timeoutMs:?):void async
  cn https_1:unknown
  cn params_1:unknown
  cn admin:unknown
  cn crypto:unknown
  cn security_1:unknown
  cn googleClientId:unknown
  cn googleClientSecret:unknown
  cn GOOGLE_AUTH_URL:literal
  cn GOOGLE_TOKEN_URL:literal
  cn GOOGLE_USERINFO_URL:literal
  cn FETCH_TIMEOUT_MS:unknown
  cn getPKCECollection:function
functions/lib/rate-limiter.js > 
  fn cleanupOldRateLimitRecords(firestore:?,hoursToKeep:?):void async
  cl FirestoreRateLimiter(2m,0p)
  cn admin:unknown
functions/lib/security.js > 
  cn admin:unknown
  cn https_1:unknown
  cn rate_limiter_1:unknown
  cn createRateLimiter:function
  cn applyRateLimit:function
  cn applySecurityHeaders:function
  cn getClientIdentifier:function
functions/src/cleanup.ts > 
  cn cleanupExpiredPKCEChallenges:unknown
  cn manualPKCECleanup:function
functions/src/createTestStudent.ts > 
  cn db:unknown
  cn createTestStudent:unknown
functions/src/customClaims.ts > 
  cn setRoleClaim:unknown
  cn syncUserRole:unknown
functions/src/emailVerification.ts > 
  fn sendEmailViaCloudflare(to:string,subject:string,html:string,text:string,workerUrl:string,apiKey:string):Promise<void> async
  fn generateVerificationCode():string
  fn isEmailAlreadyUsed(email:string):Promise<boolean> async
  fn checkRateLimit(email:string):Promise<boolean> async
  cn cloudflareWorkerUrl:unknown
  cn cloudflareApiKey:unknown
  cn db:unknown
  cn sendEmailVerificationCode:unknown
  cn verifyEmailCode:unknown
  cn cleanupExpiredVerifications:unknown
functions/src/index.ts > functions/src/cleanup,functions/src/createTestStudent,functions/src/customClaims,functions/src/emailVerification,functions/src/migrate-user-roles-cloud,functions/src/oauth
functions/src/migrate-user-roles-cloud.ts > 
  cn migrateAllUserRoles:unknown
functions/src/migrate-user-roles.ts > 
  fn migrateUserRoles():void async
functions/src/oauth.ts > functions/src/security
  fn fetchWithTimeout(url:string,options:RequestInit,timeoutMs:number):Promise<Response> async
  cn googleClientId:unknown
  cn googleClientSecret:unknown
  cn GOOGLE_AUTH_URL:literal
  cn GOOGLE_TOKEN_URL:literal
  cn GOOGLE_USERINFO_URL:literal
  cn FETCH_TIMEOUT_MS:unknown
  cn getPKCECollection:function
  cn getOAuthUrl:unknown
  cn exchangeOAuthCode:unknown
  cn refreshOAuthToken:unknown
functions/src/rate-limiter.ts > 
  fn cleanupOldRateLimitRecords(firestore:admin.firestore.Firestore,hoursToKeep:number):Promise<void> async
  cl FirestoreRateLimiter(2m,3p)
functions/src/security.ts > functions/src/rate-limiter
  cn createRateLimiter:function
  cn oauthRateLimiters:object
  cn applyRateLimit:function
  cn oauthValidator:OAuthRequestValidation
  cn securityHeaders:object
  cn applySecurityHeaders:function
  cn getClientIdentifier:function
scripts/createTestStudent.js > 
  fn createTestStudent():void async
  cn admin:unknown
  cn serviceAccount:unknown
  cn auth:unknown
  cn db:unknown