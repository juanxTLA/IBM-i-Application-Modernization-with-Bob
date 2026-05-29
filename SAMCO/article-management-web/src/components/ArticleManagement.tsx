/**
 * ArticleManagement.tsx
 * ─────────────────────────────────────────────────────────────────────────────
 * SAMCO Article Management — Carbon Design System React UI
 *
 * Replaces the green-screen ART200 / ART200D Work-with-Articles screens.
 *
 * Screen mapping:
 *   ART200 Panel 1 (SFL01 subfile list)  → DataTable with search/filter
 *   ART200 Panel 2 (FMT02 edit form)     → Modal form (Create / Edit)
 *   ART200 Panel 3 (FMT03 info text)     → Expandable row / side panel
 *   Opt 4=Delete                          → Confirmation modal
 *
 * Carbon components used:
 *   DataTable, TableToolbar, TableBatchActions, Modal,
 *   TextInput, NumberInput, Select, SelectItem,
 *   Button, Tag, InlineNotification, Loading
 * ─────────────────────────────────────────────────────────────────────────────
 */

import React, { useCallback, useEffect, useState } from 'react';
import {
  Button,
  DataTable,
  DataTableSkeleton,
  InlineNotification,
  Modal,
  NumberInput,
  Select,
  SelectItem,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableHeader,
  TableRow,
  TableToolbar,
  TableToolbarContent,
  TableToolbarSearch,
  Tag,
  TextArea,
  TextInput,
} from '@carbon/react';
import { Add, Edit, TrashCan, Information } from '@carbon/icons-react';

import {
  type Article,
  type ArticleInput,
  createArticle,
  deleteArticle,
  getArticle,
  getArticleInfo,
  listAllArticles,
  updateArticle,
} from '../services/articleService';

// ─── Table column definitions ─────────────────────────────────────────────────

const TABLE_HEADERS = [
  { key: 'id',          header: 'ID'          },
  { key: 'description', header: 'Description' },
  { key: 'familyCode',  header: 'Family'      },
  { key: 'familyDesc',  header: 'Family Description' },
  { key: 'vatCode',     header: 'VAT'         },
  { key: 'salePrice',   header: 'Sale Price'  },
  { key: 'stock',       header: 'Stock'       },
  { key: 'deleted',     header: 'Status'      },
  { key: 'actions',     header: 'Actions'     },
];

// ─── Blank form state ─────────────────────────────────────────────────────────

const BLANK_FORM: ArticleInput = {
  description: '',
  familyCode: '',
  vatCode: '',
  salePrice: 0,
  warehousePrice: 0,
  stock: 0,
  minimumQuantity: 0,
};

// ─── Component ────────────────────────────────────────────────────────────────

const ArticleManagement: React.FC = () => {
  // --- Data state ---
  const [articles, setArticles]         = useState<Article[]>([]);
  const [loading, setLoading]           = useState(true);
  const [errorMsg, setErrorMsg]         = useState<string | null>(null);
  const [successMsg, setSuccessMsg]     = useState<string | null>(null);

  // --- Modal state: create/edit ---
  const [modalOpen, setModalOpen]       = useState(false);
  const [modalMode, setModalMode]       = useState<'create' | 'edit'>('create');
  const [editingId, setEditingId]       = useState<string>('');
  const [formData, setFormData]         = useState<ArticleInput>(BLANK_FORM);
  const [formErrors, setFormErrors]     = useState<Partial<ArticleInput & { description: string }>>({});
  const [saving, setSaving]             = useState(false);

  // --- Modal state: delete confirmation ---
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [deletingId, setDeletingId]           = useState<string>('');
  const [deletingDesc, setDeletingDesc]       = useState<string>('');

  // --- Modal state: article info (FMT03) ---
  const [infoModalOpen, setInfoModalOpen]   = useState(false);
  const [infoArticle, setInfoArticle]       = useState<Article | null>(null);
  const [infoText, setInfoText]             = useState<string>('');
  const [infoLoading, setInfoLoading]       = useState(false);

  // --- Search / filter ---
  const [searchTerm, setSearchTerm]     = useState('');

  // ── Load articles ────────────────────────────────────────────────────────────

  const loadArticles = useCallback(async () => {
    setLoading(true);
    setErrorMsg(null);
    try {
      const result = await listAllArticles();
      if (result.success) {
        setArticles(result.articleData ?? []);
      } else {
        setErrorMsg(result.message);
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Failed to load articles');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadArticles();
  }, [loadArticles]);

  // ── Filtered rows for DataTable ───────────────────────────────────────────

  const filteredArticles = articles.filter((a) => {
    const term = searchTerm.toLowerCase();
    return (
      a.id.toLowerCase().includes(term) ||
      a.description.toLowerCase().includes(term) ||
      a.familyCode.toLowerCase().includes(term) ||
      a.familyDesc.toLowerCase().includes(term)
    );
  });

  // Map to DataTable rows (add string `id` required by Carbon)
  const tableRows = filteredArticles.map((a) => ({
    ...a,
    id: a.id.trim(),  // Carbon DataTable requires `id` to be the row key
  }));

  // ── Create / Edit modal handlers ──────────────────────────────────────────

  const openCreateModal = () => {
    setModalMode('create');
    setEditingId('');
    setFormData(BLANK_FORM);
    setFormErrors({});
    setModalOpen(true);
  };

  const openEditModal = async (id: string) => {
    setModalMode('edit');
    setEditingId(id);
    setFormErrors({});
    setModalOpen(true);
    try {
      const result = await getArticle(id);
      if (result.success) {
        const a = result.article;
        setFormData({
          description:    a.description,
          familyCode:     a.familyCode,
          vatCode:        a.vatCode,
          salePrice:      a.salePrice,
          warehousePrice: a.warehousePrice,
          stock:          a.stock,
          minimumQuantity: a.minimumQuantity,
        });
      } else {
        setErrorMsg(result.message);
        setModalOpen(false);
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Failed to load article');
      setModalOpen(false);
    }
  };

  const validateForm = (): boolean => {
    const errors: Partial<ArticleInput & { description: string }> = {};
    if (!formData.description.trim()) {
      errors.description = 'Description is mandatory';
    }
    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSave = async () => {
    if (!validateForm()) return;
    setSaving(true);
    setErrorMsg(null);
    try {
      const result =
        modalMode === 'create'
          ? await createArticle(formData)
          : await updateArticle(editingId, formData);
      if (result.success) {
        setSuccessMsg(result.message);
        setModalOpen(false);
        void loadArticles();
      } else {
        setErrorMsg(result.message);
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  // ── Delete handlers ───────────────────────────────────────────────────────

  const openDeleteModal = (id: string, description: string) => {
    setDeletingId(id);
    setDeletingDesc(description);
    setDeleteModalOpen(true);
  };

  const handleDelete = async () => {
    setErrorMsg(null);
    try {
      const result = await deleteArticle(deletingId);
      if (result.success) {
        setSuccessMsg(result.message);
        setDeleteModalOpen(false);
        void loadArticles();
      } else {
        setErrorMsg(result.message);
      }
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Delete failed');
    }
  };

  // ── Article Info (FMT03) handler ──────────────────────────────────────────

  const openInfoModal = async (article: Article) => {
    setInfoArticle(article);
    setInfoText('');
    setInfoLoading(true);
    setInfoModalOpen(true);
    try {
      const result = await getArticleInfo(article.id);
      setInfoText(result.information ?? '');
    } catch (err) {
      setInfoText('');
    } finally {
      setInfoLoading(false);
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <div className="article-management">

      {/* Page header */}
      <div style={{ marginBottom: '1.5rem' }}>
        <h1 style={{ fontSize: '1.75rem', fontWeight: 600 }}>
          Work with Articles
        </h1>
        <p style={{ color: '#6f6f6f', marginTop: '0.25rem' }}>
          Replaces ART200 green screen — {articles.length} article(s) loaded
        </p>
      </div>

      {/* Inline notifications */}
      {errorMsg && (
        <InlineNotification
          kind="error"
          title="Error"
          subtitle={errorMsg}
          onCloseButtonClick={() => setErrorMsg(null)}
          style={{ marginBottom: '1rem' }}
        />
      )}
      {successMsg && (
        <InlineNotification
          kind="success"
          title="Success"
          subtitle={successMsg}
          onCloseButtonClick={() => setSuccessMsg(null)}
          style={{ marginBottom: '1rem' }}
        />
      )}

      {/* Article list table */}
      {loading ? (
        <DataTableSkeleton headers={TABLE_HEADERS} rowCount={10} />
      ) : (
        <DataTable rows={tableRows} headers={TABLE_HEADERS} isSortable>
          {({
            rows,
            headers,
            getHeaderProps,
            getRowProps,
            getTableProps,
            getToolbarProps,
            getTableContainerProps,
          }: {
            rows: typeof tableRows;
            headers: typeof TABLE_HEADERS;
            getHeaderProps: (args: { header: (typeof TABLE_HEADERS)[0] }) => Record<string, unknown>;
            getRowProps: (args: { row: (typeof tableRows)[0] }) => Record<string, unknown>;
            getTableProps: () => Record<string, unknown>;
            getToolbarProps: () => Record<string, unknown>;
            getTableContainerProps: () => Record<string, unknown>;
          }) => (
            <TableContainer
              title=""
              {...getTableContainerProps()}
            >
              <TableToolbar {...getToolbarProps()}>
                <TableToolbarContent>
                  <TableToolbarSearch
                    placeholder="Search by ID, description or family…"
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
                      setSearchTerm(e.target.value)
                    }
                    persistent
                  />
                  <Button
                    renderIcon={Add}
                    onClick={openCreateModal}
                    size="sm"
                  >
                    Create Article (F6)
                  </Button>
                </TableToolbarContent>
              </TableToolbar>

              <Table {...getTableProps()} size="sm">
                <TableHead>
                  <TableRow>
                    {headers.map((header) => (
                      <TableHeader
                        key={header.key}
                        {...getHeaderProps({ header })}
                      >
                        {header.header}
                      </TableHeader>
                    ))}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {rows.map((row) => {
                    const article = filteredArticles.find(
                      (a) => a.id.trim() === row.id
                    );
                    return (
                      <TableRow key={row.id} {...getRowProps({ row })}>
                        <TableCell>{row.id}</TableCell>
                        <TableCell>{(row as unknown as Article).description}</TableCell>
                        <TableCell>{(row as unknown as Article).familyCode}</TableCell>
                        <TableCell>{(row as unknown as Article).familyDesc}</TableCell>
                        <TableCell>{(row as unknown as Article).vatCode}</TableCell>
                        <TableCell>
                          {(row as unknown as Article).salePrice?.toFixed(2)}
                        </TableCell>
                        <TableCell>
                          {(row as unknown as Article).stock}
                        </TableCell>
                        <TableCell>
                          {(row as unknown as Article).deleted === 'X' ? (
                            <Tag type="red">Deleted</Tag>
                          ) : (
                            <Tag type="green">Active</Tag>
                          )}
                        </TableCell>
                        <TableCell>
                          <div style={{ display: 'flex', gap: '0.25rem' }}>
                            {/* Opt 2=Edit */}
                            <Button
                              kind="ghost"
                              size="sm"
                              renderIcon={Edit}
                              iconDescription="Edit (Opt 2)"
                              hasIconOnly
                              onClick={() => void openEditModal(row.id)}
                              tooltipPosition="top"
                            />
                            {/* Opt 3=Info */}
                            <Button
                              kind="ghost"
                              size="sm"
                              renderIcon={Information}
                              iconDescription="Info (Opt 3)"
                              hasIconOnly
                              onClick={() =>
                                article && void openInfoModal(article)
                              }
                              tooltipPosition="top"
                            />
                            {/* Opt 4=Delete */}
                            <Button
                              kind="danger--ghost"
                              size="sm"
                              renderIcon={TrashCan}
                              iconDescription="Delete (Opt 4)"
                              hasIconOnly
                              onClick={() =>
                                openDeleteModal(
                                  row.id,
                                  (row as unknown as Article).description
                                )
                              }
                              tooltipPosition="top"
                            />
                          </div>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </DataTable>
      )}

      {/* ── Create / Edit Modal (ART200 FMT02 equivalent) ──────────────────── */}
      <Modal
        open={modalOpen}
        modalHeading={
          modalMode === 'create' ? 'Create Article' : `Edit Article — ${editingId}`
        }
        primaryButtonText={saving ? 'Saving…' : 'Save'}
        secondaryButtonText="Cancel (F12)"
        onRequestSubmit={() => void handleSave()}
        onRequestClose={() => setModalOpen(false)}
        onSecondarySubmit={() => setModalOpen(false)}
        primaryButtonDisabled={saving}
        size="md"
      >
        <TextInput
          id="art-description"
          labelText="Description *"
          value={formData.description}
          onChange={(e) =>
            setFormData((f) => ({ ...f, description: e.target.value }))
          }
          invalid={!!formErrors.description}
          invalidText={formErrors.description}
          maxLength={50}
          style={{ marginBottom: '1rem' }}
        />
        <TextInput
          id="art-family"
          labelText="Family Code"
          value={formData.familyCode}
          onChange={(e) =>
            setFormData((f) => ({ ...f, familyCode: e.target.value }))
          }
          maxLength={3}
          style={{ marginBottom: '1rem' }}
        />
        <Select
          id="art-vatcode"
          labelText="VAT Code"
          value={formData.vatCode}
          onChange={(e) =>
            setFormData((f) => ({ ...f, vatCode: e.target.value }))
          }
          style={{ marginBottom: '1rem' }}
        >
          <SelectItem value="" text="— Select —" />
          <SelectItem value="0" text="0 — Exempt (0%)" />
          <SelectItem value="1" text="1 — Reduced rate" />
          <SelectItem value="2" text="2 — Standard rate" />
        </Select>
        <NumberInput
          id="art-saleprice"
          label="Reference Sale Price"
          value={formData.salePrice}
          onChange={(_e: React.MouseEvent, { value }: { value: number | string }) =>
            setFormData((f) => ({ ...f, salePrice: Number(value) }))
          }
          min={0}
          step={0.01}
          style={{ marginBottom: '1rem' }}
        />
        <NumberInput
          id="art-whsprice"
          label="Warehouse Price"
          value={formData.warehousePrice}
          onChange={(_e: React.MouseEvent, { value }: { value: number | string }) =>
            setFormData((f) => ({ ...f, warehousePrice: Number(value) }))
          }
          min={0}
          step={0.01}
          style={{ marginBottom: '1rem' }}
        />
        <NumberInput
          id="art-stock"
          label="Stock"
          value={formData.stock}
          onChange={(_e: React.MouseEvent, { value }: { value: number | string }) =>
            setFormData((f) => ({ ...f, stock: Number(value) }))
          }
          min={0}
          style={{ marginBottom: '1rem' }}
        />
        <NumberInput
          id="art-minstock"
          label="Minimum Stock"
          value={formData.minimumQuantity}
          onChange={(_e: React.MouseEvent, { value }: { value: number | string }) =>
            setFormData((f) => ({ ...f, minimumQuantity: Number(value) }))
          }
          min={0}
        />
      </Modal>

      {/* ── Delete Confirmation Modal (ART200 Opt 4 equivalent) ────────────── */}
      <Modal
        open={deleteModalOpen}
        danger
        modalHeading="Confirm Delete"
        primaryButtonText="Delete (Opt 4)"
        secondaryButtonText="Cancel (F12)"
        onRequestSubmit={() => void handleDelete()}
        onRequestClose={() => setDeleteModalOpen(false)}
        onSecondarySubmit={() => setDeleteModalOpen(false)}
        size="sm"
      >
        <p>
          Are you sure you want to delete article{' '}
          <strong>{deletingId}</strong> — {deletingDesc}?
        </p>
        <p style={{ marginTop: '0.5rem', color: '#6f6f6f', fontSize: '0.875rem' }}>
          This sets ARDEL=X (soft delete). The record is not physically removed.
        </p>
      </Modal>

      {/* ── Article Info Modal (ART200 FMT03 / Opt 3 equivalent) ───────────── */}
      <Modal
        open={infoModalOpen}
        modalHeading={
          infoArticle
            ? `Article Information — ${infoArticle.id.trim()} ${infoArticle.description}`
            : 'Article Information'
        }
        passiveModal
        onRequestClose={() => setInfoModalOpen(false)}
        size="lg"
      >
        {infoLoading ? (
          <p style={{ color: '#6f6f6f' }}>Loading information…</p>
        ) : (
          <>
            {infoArticle && (
              <dl style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem 2rem', marginBottom: '1rem' }}>
                <dt style={{ fontWeight: 600 }}>Family</dt>
                <dd>{infoArticle.familyCode} — {infoArticle.familyDesc}</dd>
                <dt style={{ fontWeight: 600 }}>VAT Code</dt>
                <dd>{infoArticle.vatCode} ({infoArticle.vatRate}%)</dd>
                <dt style={{ fontWeight: 600 }}>Sale Price</dt>
                <dd>{infoArticle.salePrice?.toFixed(2)}</dd>
                <dt style={{ fontWeight: 600 }}>Warehouse Price</dt>
                <dd>{infoArticle.warehousePrice?.toFixed(2)}</dd>
                <dt style={{ fontWeight: 600 }}>Stock</dt>
                <dd>{infoArticle.stock} (min: {infoArticle.minimumQuantity})</dd>
                <dt style={{ fontWeight: 600 }}>Created</dt>
                <dd>{infoArticle.creationDate}</dd>
                <dt style={{ fontWeight: 600 }}>Last Modified</dt>
                <dd>{infoArticle.lastModified} by {infoArticle.lastModifiedBy}</dd>
              </dl>
            )}
            <TextArea
              id="art-info-text"
              labelText="Article Information (long text)"
              value={infoText}
              readOnly
              rows={8}
            />
          </>
        )}
      </Modal>

    </div>
  );
};

export default ArticleManagement;
