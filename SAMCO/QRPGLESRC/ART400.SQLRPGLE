**FREE
//==============================================================================
// Program: ART400 - Article REST API Service Program Module
// Description: Full CRUD REST API for Article Management
//              Designed for IBM i Integrated Web Services (IWS)
//              PGMINFO(*PCML:*MODULE:*DCLCASE) exposes procedures to IWS
//
// Procedures (IWS Endpoints):
//   ListAllArticles  → GET    /articles
//   GetArticle       → GET    /articles/{id}
//   CreateArticle    → POST   /articles
//   UpdateArticle    → PUT    /articles/{id}
//   DeleteArticle    → DELETE /articles/{id}
//   GetArticleInfo   → GET    /articles/{id}/info
//
// Author: Bob / SAMCO Modernization
// Date: 2025-01-01
//==============================================================================

Ctl-Opt NoMain PGMINFO(*PCML : *MODULE : *DCLCASE);
Ctl-Opt DatFmt(*ISO);
Ctl-Opt TimFmt(*ISO);

//==============================================================================
// Shared Data Structures
// *DCLCASE ensures camelCase field names flow through to JSON as-is
//==============================================================================

// --- Single Article Item (used in list and single-get responses) ---
Dcl-Ds ArticleItem Qualified Template;
  id           Char(6);
  description  Char(50);
  familyCode   Char(3);
  familyDesc   Char(50);
  vatCode      Char(1);
  vatRate      Packed(4:2);
  salePrice    Packed(7:2);
  warehousePrice Packed(7:2);
  stock        Packed(5:0);
  minimumQuantity Packed(5:0);
  deleted      Char(1);
  creationDate Char(10);       // ISO date as char for JSON
  lastModified Char(26);       // ISO timestamp as char for JSON
  lastModifiedBy Char(11);
End-Ds;

// --- Article Input (POST/PUT request body) ---
// IWS maps the JSON request body to this DS
Dcl-Ds ArticleInput Qualified Template;
  id           Char(6);
  description  Char(50);
  familyCode   Char(3);
  vatCode      Char(1);
  salePrice    Packed(7:2);
  warehousePrice Packed(7:2);
  stock        Packed(5:0);
  minimumQuantity Packed(5:0);
End-Ds;

// --- Standard API Response (single article) ---
Dcl-Ds ArticleResponse Qualified Template;
  success  Ind;
  message  Char(256);
  article  LikeDs(ArticleItem);
End-Ds;

// --- Standard API Response (article list) ---
Dcl-Ds ArticleListResponse Qualified Template;
  success      Ind;
  message      Char(256);
  totalRecords Int(10);
  articleCount Int(10);
  articleData  LikeDs(ArticleItem) Dim(1000);
End-Ds;

// --- Standard API Response (no data, for create/update/delete) ---
Dcl-Ds ApiResponse Qualified Template;
  success Ind;
  message Char(256);
  id      Char(6);
End-Ds;

// --- Article Info (long text) ---
Dcl-Ds ArticleInfoResponse Qualified Template;
  success     Ind;
  message     Char(256);
  id          Char(6);
  information Char(1520);
End-Ds;


//==============================================================================
// Procedure: ListAllArticles
// IWS mapping: GET /articles
// Parameters: None
// Returns:    ArticleListResponse (all non-deleted articles)
//==============================================================================
Dcl-Proc ListAllArticles Export;
  Dcl-Pi *N LikeDs(ArticleListResponse);
  End-Pi;

  Dcl-Ds  response LikeDs(ArticleListResponse);
  Dcl-Ds  tempItem LikeDs(ArticleItem);
  Dcl-S   i Int(10);

  Clear response;
  response.success = *Off;

  Exec SQL
    DECLARE C_LIST CURSOR FOR
    SELECT
      A.ARID,
      A.ARDESC,
      COALESCE(RTRIM(A.ARTIFA), ''),
      COALESCE(RTRIM(F.FADESC), ''),
      COALESCE(RTRIM(A.ARVATCD), ''),
      COALESCE(V.VATRATE, 0),
      A.ARSALEPR,
      A.ARWHSPR,
      A.ARSTOCK,
      A.ARMINQTY,
      A.ARDEL,
      COALESCE(CHAR(A.ARCREA, ISO), ''),
      COALESCE(CHAR(A.ARMOD), ''),
      COALESCE(RTRIM(A.ARMODID), '')
    FROM ARTICLE A
    LEFT JOIN FAMILLY F ON A.ARTIFA = F.FAID
    LEFT JOIN VATDEF  V ON A.ARVATCD = V.VATCODE
    WHERE A.ARDEL = ' '
    ORDER BY A.ARDESC;

  Exec SQL OPEN C_LIST;

  If SQLCODE = 0;
    i = 1;
    DoU SQLCODE <> 0 Or i > 1000;
      Clear tempItem;
      Exec SQL
        FETCH C_LIST INTO
          :tempItem.id,
          :tempItem.description,
          :tempItem.familyCode,
          :tempItem.familyDesc,
          :tempItem.vatCode,
          :tempItem.vatRate,
          :tempItem.salePrice,
          :tempItem.warehousePrice,
          :tempItem.stock,
          :tempItem.minimumQuantity,
          :tempItem.deleted,
          :tempItem.creationDate,
          :tempItem.lastModified,
          :tempItem.lastModifiedBy;
      If SQLCODE = 0;
        response.articleData(i) = tempItem;
        i += 1;
      EndIf;
    EndDo;
    response.articleCount = i - 1;
    response.totalRecords  = response.articleCount;
    response.success       = *On;
    response.message       = 'Articles retrieved successfully';
  Else;
    response.message = 'Error retrieving articles. SQLCODE: ' + %Char(SQLCODE);
  EndIf;

  Exec SQL CLOSE C_LIST;

  Return response;
End-Proc;


//==============================================================================
// Procedure: GetArticle
// IWS mapping: GET /articles/{id}
// Parameters: pId (6A) — article ID from URL path parameter
// Returns:    ArticleResponse (single article detail)
//==============================================================================
Dcl-Proc GetArticle Export;
  Dcl-Pi *N LikeDs(ArticleResponse);
    pId Char(6) Const;
  End-Pi;

  Dcl-Ds response LikeDs(ArticleResponse);

  Clear response;
  response.success = *Off;

  Exec SQL
    SELECT
      A.ARID,
      A.ARDESC,
      COALESCE(RTRIM(A.ARTIFA), ''),
      COALESCE(RTRIM(F.FADESC), ''),
      COALESCE(RTRIM(A.ARVATCD), ''),
      COALESCE(V.VATRATE, 0),
      A.ARSALEPR,
      A.ARWHSPR,
      A.ARSTOCK,
      A.ARMINQTY,
      A.ARDEL,
      COALESCE(CHAR(A.ARCREA, ISO), ''),
      COALESCE(CHAR(A.ARMOD), ''),
      COALESCE(RTRIM(A.ARMODID), '')
    INTO
      :response.article.id,
      :response.article.description,
      :response.article.familyCode,
      :response.article.familyDesc,
      :response.article.vatCode,
      :response.article.vatRate,
      :response.article.salePrice,
      :response.article.warehousePrice,
      :response.article.stock,
      :response.article.minimumQuantity,
      :response.article.deleted,
      :response.article.creationDate,
      :response.article.lastModified,
      :response.article.lastModifiedBy
    FROM ARTICLE A
    LEFT JOIN FAMILLY F ON A.ARTIFA = F.FAID
    LEFT JOIN VATDEF  V ON A.ARVATCD = V.VATCODE
    WHERE A.ARID = :pId;

  Select;
    When SQLCODE = 0;
      response.success = *On;
      response.message = 'Article retrieved successfully';
    When SQLCODE = 100;
      response.message = 'Article not found: ' + %Trim(pId);
    Other;
      response.message = 'Error retrieving article. SQLCODE: ' + %Char(SQLCODE);
  EndSl;

  Return response;
End-Proc;


//==============================================================================
// Procedure: CreateArticle
// IWS mapping: POST /articles
// Parameters: pArticle (ArticleInput DS) — request body (JSON → DS by IWS)
// Returns:    ApiResponse with new article ID
//==============================================================================
Dcl-Proc CreateArticle Export;
  Dcl-Pi *N LikeDs(ApiResponse);
    pArticle LikeDs(ArticleInput) Const;
  End-Pi;

  Dcl-Ds  response LikeDs(ApiResponse);
  Dcl-S   newId    Char(6);
  Dcl-S   newIdNum Packed(6:0);
  Dcl-S   currentUser Char(11);

  Clear response;
  response.success = *Off;

  // Validate mandatory fields
  If %Trim(pArticle.description) = '';
    response.message = 'Description is mandatory';
    Return response;
  EndIf;

  // Validate family code exists (if provided)
  If %Trim(pArticle.familyCode) <> '';
    Exec SQL
      SELECT COUNT(*) INTO :newIdNum
      FROM FAMILLY
      WHERE FAID = :pArticle.familyCode
        AND FADEL = ' ';
    If newIdNum = 0;
      response.message = 'Family code not found: ' + %Trim(pArticle.familyCode);
      Return response;
    EndIf;
  EndIf;

  // Auto-generate next article ID (max existing numeric ID + 1)
  Exec SQL
    SELECT COALESCE(MAX(INTEGER(ARID)), 0) + 1
    INTO :newIdNum
    FROM ARTICLE
    WHERE ARID BETWEEN '000001' AND '999999';

  newId = %EditC(newIdNum : 'X');

  // Get current user
  Exec SQL VALUES(CURRENT_USER) INTO :currentUser;

  // Insert new article
  Exec SQL
    INSERT INTO ARTICLE
      (ARID, ARDESC, ARTIFA, ARVATCD,
       ARSALEPR, ARWHSPR, ARSTOCK, ARMINQTY,
       ARDEL, ARCREA, ARMOD, ARMODID)
    VALUES
      (:newId,
       :pArticle.description,
       :pArticle.familyCode,
       :pArticle.vatCode,
       :pArticle.salePrice,
       :pArticle.warehousePrice,
       :pArticle.stock,
       :pArticle.minimumQuantity,
       ' ',
       CURRENT_DATE,
       CURRENT_TIMESTAMP,
       :currentUser);

  Select;
    When SQLCODE = 0;
      response.success = *On;
      response.id      = newId;
      response.message = 'Article created successfully. ID: ' + %Trim(newId);
    Other;
      response.message = 'Error creating article. SQLCODE: ' + %Char(SQLCODE);
  EndSl;

  Return response;
End-Proc;


//==============================================================================
// Procedure: UpdateArticle
// IWS mapping: PUT /articles/{id}
// Parameters: pId      (6A)           — article ID from URL path parameter
//             pArticle (ArticleInput) — request body (JSON → DS by IWS)
// Returns:    ApiResponse
//==============================================================================
Dcl-Proc UpdateArticle Export;
  Dcl-Pi *N LikeDs(ApiResponse);
    pId      Char(6)              Const;
    pArticle LikeDs(ArticleInput) Const;
  End-Pi;

  Dcl-Ds response    LikeDs(ApiResponse);
  Dcl-S  currentUser Char(11);
  Dcl-S  checkCount  Int(10);

  Clear response;
  response.success = *Off;
  response.id      = pId;

  // Validate mandatory fields
  If %Trim(pArticle.description) = '';
    response.message = 'Description is mandatory';
    Return response;
  EndIf;

  // Check article exists and is not deleted
  Exec SQL
    SELECT COUNT(*) INTO :checkCount
    FROM ARTICLE
    WHERE ARID = :pId AND ARDEL = ' ';

  If checkCount = 0;
    response.message = 'Article not found or already deleted: ' + %Trim(pId);
    Return response;
  EndIf;

  // Validate family code exists (if provided)
  If %Trim(pArticle.familyCode) <> '';
    Exec SQL
      SELECT COUNT(*) INTO :checkCount
      FROM FAMILLY
      WHERE FAID = :pArticle.familyCode AND FADEL = ' ';
    If checkCount = 0;
      response.message = 'Family code not found: ' + %Trim(pArticle.familyCode);
      Return response;
    EndIf;
  EndIf;

  // Get current user
  Exec SQL VALUES(CURRENT_USER) INTO :currentUser;

  // Update article
  Exec SQL
    UPDATE ARTICLE
    SET
      ARDESC   = :pArticle.description,
      ARTIFA   = :pArticle.familyCode,
      ARVATCD  = :pArticle.vatCode,
      ARSALEPR = :pArticle.salePrice,
      ARWHSPR  = :pArticle.warehousePrice,
      ARSTOCK  = :pArticle.stock,
      ARMINQTY = :pArticle.minimumQuantity,
      ARMOD    = CURRENT_TIMESTAMP,
      ARMODID  = :currentUser
    WHERE ARID = :pId
      AND ARDEL = ' ';

  Select;
    When SQLCODE = 0;
      response.success = *On;
      response.message = 'Article updated successfully';
    Other;
      response.message = 'Error updating article. SQLCODE: ' + %Char(SQLCODE);
  EndSl;

  Return response;
End-Proc;


//==============================================================================
// Procedure: DeleteArticle
// IWS mapping: DELETE /articles/{id}
// Soft-delete: sets ARDEL = 'X' — mirrors green screen Opt 4=Delete
// Parameters: pId (6A) — article ID from URL path parameter
// Returns:    ApiResponse
//==============================================================================
Dcl-Proc DeleteArticle Export;
  Dcl-Pi *N LikeDs(ApiResponse);
    pId Char(6) Const;
  End-Pi;

  Dcl-Ds response    LikeDs(ApiResponse);
  Dcl-S  currentUser Char(11);
  Dcl-S  checkCount  Int(10);

  Clear response;
  response.success = *Off;
  response.id      = pId;

  // Check article exists and is not already deleted
  Exec SQL
    SELECT COUNT(*) INTO :checkCount
    FROM ARTICLE
    WHERE ARID = :pId AND ARDEL = ' ';

  If checkCount = 0;
    response.message = 'Article not found or already deleted: ' + %Trim(pId);
    Return response;
  EndIf;

  // Get current user
  Exec SQL VALUES(CURRENT_USER) INTO :currentUser;

  // Soft delete — same logic as ART200 Opt 4 (ARDEL = 'X')
  Exec SQL
    UPDATE ARTICLE
    SET
      ARDEL   = 'X',
      ARMOD   = CURRENT_TIMESTAMP,
      ARMODID = :currentUser
    WHERE ARID = :pId;

  Select;
    When SQLCODE = 0;
      response.success = *On;
      response.message = 'Article deleted successfully';
    Other;
      response.message = 'Error deleting article. SQLCODE: ' + %Char(SQLCODE);
  EndSl;

  Return response;
End-Proc;


//==============================================================================
// Procedure: GetArticleInfo
// IWS mapping: GET /articles/{id}/info
// Description: Returns the long-form article information (free text)
//              Mirrors green screen FMT03 panel (article information)
// Parameters: pId (6A) — article ID from URL path parameter
// Returns:    ArticleInfoResponse
//==============================================================================
Dcl-Proc GetArticleInfo Export;
  Dcl-Pi *N LikeDs(ArticleInfoResponse);
    pId Char(6) Const;
  End-Pi;

  Dcl-Ds response LikeDs(ArticleInfoResponse);

  Clear response;
  response.success = *Off;
  response.id      = pId;

  Exec SQL
    SELECT ARTICLE_INFORMATION
    INTO   :response.information
    FROM   ARTIINF
    WHERE  ARTICLE_INFO_ID = :pId;

  Select;
    When SQLCODE = 0;
      response.success = *On;
      response.message = 'Article information retrieved successfully';
    When SQLCODE = 100;
      response.success = *On;         // Not an error — info may be empty
      response.information = '';
      response.message = 'No information available for article: ' + %Trim(pId);
    Other;
      response.message = 'Error retrieving article info. SQLCODE: ' + %Char(SQLCODE);
  EndSl;

  Return response;
End-Proc;
