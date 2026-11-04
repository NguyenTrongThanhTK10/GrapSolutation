// Keep navigation aligned with the API's role checks; the server remains authoritative.
const staff = ['OperationsAdmin', 'Dispatcher', 'DriverReviewer', 'SupportAgent', 'FinanceOperator', 'FinanceApprover', 'SecurityAdmin'];
const routes: Record<string, string[]> = {
  '/': staff,
  '/dispatch': ['OperationsAdmin', 'Dispatcher'],
  '/rides': ['OperationsAdmin', 'Dispatcher', 'SupportAgent', 'FinanceOperator', 'FinanceApprover'],
  '/drivers': ['OperationsAdmin', 'Dispatcher', 'DriverReviewer', 'FinanceOperator', 'FinanceApprover'],
  '/customers': ['OperationsAdmin', 'SecurityAdmin', 'SupportAgent'],
  '/pricing': ['OperationsAdmin', 'Dispatcher'],
  '/finance': ['FinanceOperator', 'FinanceApprover'],
  '/support': ['OperationsAdmin', 'SupportAgent'],
  '/audit': ['OperationsAdmin', 'SecurityAdmin'],
  '/settings': staff,
  '/customer': ['Customer'],
  '/driver': ['Driver'],
};

export function canAccess(path: string, role?: string) {
  return !!role && (routes[path]?.includes(role) ?? false);
}

export function homeFor(role?: string) {
  return role === 'Customer' ? '/customer' : role === 'Driver' ? '/driver' : '/';
}
