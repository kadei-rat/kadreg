// Table sorting functionality
document.addEventListener('DOMContentLoaded', function() {
  const membersTable = document.getElementById('members-table');
  if (!membersTable) return;

  const sortableHeaders = membersTable.querySelectorAll('th.sortable');

  sortableHeaders.forEach(header => {
    header.addEventListener('click', function() {
      const table = this.closest('table');
      const tbody = table.querySelector('tbody');
      const rows = Array.from(tbody.querySelectorAll('tr'));
      const columnIndex = Array.from(this.parentNode.children).indexOf(this);

      // Determine sort direction
      const isAscending = !this.classList.contains('sort-asc');

      // Clear all sort classes
      sortableHeaders.forEach(h => h.classList.remove('sort-asc', 'sort-desc'));

      // Add appropriate sort class
      this.classList.add(isAscending ? 'sort-asc' : 'sort-desc');

      // Sort rows
      rows.sort((a, b) => {
        const aVal = a.children[columnIndex].textContent.trim();
        const bVal = b.children[columnIndex].textContent.trim();

        // Handle numeric sorting for ID column
        if (columnIndex === 0) {
          const aNum = parseInt(aVal.replace(/[^\d]/g, ''));
          const bNum = parseInt(bVal.replace(/[^\d]/g, ''));
          return isAscending ? aNum - bNum : bNum - aNum;
        }

        // Handle date sorting for joined column
        if (columnIndex === 5) {
          const aDate = new Date(aVal);
          const bDate = new Date(bVal);
          return isAscending ? aDate - bDate : bDate - aDate;
        }

        // Default string sorting
        return isAscending ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal);
      });

      // Re-append sorted rows
      rows.forEach(row => tbody.appendChild(row));
    });
  });
});

// Table search functionality
document.addEventListener('DOMContentLoaded', function() {
  const searchInput = document.getElementById('member-search');
  if (!searchInput) return;

  const membersTable = document.getElementById('members-table');
  if (!membersTable) return;

  const tbody = membersTable.querySelector('tbody');
  const rows = tbody.querySelectorAll('tr');

  searchInput.addEventListener('input', function() {
    const searchTerm = this.value.toLowerCase().trim();

    rows.forEach(row => {
      const cells = row.querySelectorAll('td');
      const text = Array.from(cells).map(cell => cell.textContent.toLowerCase()).join(' ');

      if (text.includes(searchTerm)) {
        row.style.display = '';
      } else {
        row.style.display = 'none';
      }
    });
  });
});
