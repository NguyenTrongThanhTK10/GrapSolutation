<script setup lang="ts">
import {ref} from 'vue';
import Button from 'primevue/button';
import Dialog from 'primevue/dialog';
import Select from 'primevue/select';
import Textarea from 'primevue/textarea';
import {useToast} from 'primevue/usetoast';
import {api} from '../lib/api';
import type {Data} from '../lib/types';
import {useQuery} from '../composables/useQuery';
import QueryState from './QueryState.vue';
const {data,loading,error,refresh}=useQuery(()=>api('/admin/account-deletion-requests'));
const selected=ref<Data|null>(null),decision=ref('IN_REVIEW'),reason=ref(''),busy=ref(false),toast=useToast();
const thread=ref<Data|null>(null),message=ref('');
async function openThread(id:string){try{thread.value=await api('/support/tickets/'+id);message.value='';}catch(e){toast.add({severity:'error',summary:(e as Error).message,life:5000});}}
async function reply(){if(!thread.value)return;busy.value=true;try{const id=thread.value.ticket.id;await api('/support/tickets/'+id+'/messages',{method:'POST',body:{body:message.value.trim()}});await openThread(id);}catch(e){toast.add({severity:'error',summary:(e as Error).message,life:5000});}finally{busy.value=false;}}
const openStates=['REQUESTED','BLOCKED_OBLIGATIONS','IN_REVIEW','NEEDS_INFORMATION'];
const labels:Record<string,string>={REQUESTED:'Mới gửi',BLOCKED_OBLIGATIONS:'Còn nghĩa vụ',IN_REVIEW:'Đang kiểm tra',NEEDS_INFORMATION:'Cần bổ sung',REJECTED:'Từ chối',WITHDRAWN:'Đã rút'};
const blockers:Record<string,string>={ACTIVE_RIDE:'Chuyến đang diễn ra',OUTSTANDING_PAYMENT:'Chưa hoàn tất thanh toán',DRIVER_BALANCE_PENDING:'Cần đối soát số dư tài xế'};
async function review(){if(!selected.value)return;busy.value=true;try{await api(`/admin/account-deletion-requests/${selected.value.id}/review`,{method:'POST',idempotent:true,body:{expectedVersion:selected.value.version,decision:decision.value,reason:reason.value.trim()}});selected.value=null;await refresh();toast.add({severity:'success',summary:'Đã cập nhật yêu cầu',life:3000});}catch(e){toast.add({severity:'error',summary:(e as Error).message,life:5000});await refresh();}finally{busy.value=false;}}
</script>
<template>
  <section class="panel">
    <div class="panel-header"><div><h2>Yêu cầu xóa tài khoản</h2><p>Kiểm tra nghĩa vụ và trao đổi với người dùng qua phiếu hỗ trợ.</p></div><Button icon="pi pi-refresh" label="Làm mới" text @click="refresh"/></div>
    <div class="settings-body"><p class="muted">Đây là quy trình tiếp nhận và kiểm tra. Dữ liệu chưa bị xóa; tác vụ xóa tự động chưa được bật.</p><QueryState :loading="loading" :error="error" @retry="refresh"/>
      <p v-if="data && !data.items.length">Chưa có yêu cầu.</p>
      <article v-for="r in data?.items" :key="r.id" class="privacy-request">
        <div class="heading-actions"><strong>{{labels[r.status]??r.status}}</strong><small>{{new Date(r.createdAt).toLocaleString('vi-VN')}}</small></div>
        <p>{{r.reason}}</p><p v-for="b in r.blockers" :key="b" class="privacy-blocker">{{blockers[b]??b}}</p><p v-if="r.reviewNote">Phản hồi gần nhất: {{r.reviewNote}}</p>
        <div class="heading-actions"><Button text label="Phiếu hỗ trợ liên quan" @click="openThread(r.ticketId)"/><Button v-if="openStates.includes(r.status)" label="Xử lý yêu cầu" size="small" outlined @click="selected=r;decision=r.blockers.length?'NEEDS_INFORMATION':'IN_REVIEW';reason=''"/></div>
      </article>
    </div>
  </section>
  <Dialog :visible="selected!==null" modal header="Kiểm tra yêu cầu xóa tài khoản" :style="{width:'32rem',maxWidth:'95vw'}" @update:visible="v=>{if(!v&&!busy)selected=null}">
    <div class="privacy-form"><label>Quyết định<Select v-model="decision" class="full-width" :disabled="busy" :options="[{label:'Tiếp nhận kiểm tra',value:'IN_REVIEW'},{label:'Yêu cầu bổ sung',value:'NEEDS_INFORMATION'},{label:'Từ chối yêu cầu',value:'REJECTED'}]" optionLabel="label" optionValue="value"/></label>
      <label>Lý do / hướng dẫn cho người dùng<Textarea v-model="reason" :disabled="busy" :maxlength="1000" rows="5" class="full-width"/></label>
      <p v-if="selected?.blockers.length">Cần xử lý nghĩa vụ trước khi tiếp nhận kiểm tra.</p>
    </div><template #footer><Button label="Hủy" text :disabled="busy" @click="selected=null"/><Button label="Lưu phản hồi" :loading="busy" :disabled="reason.trim().length<5 || (decision==='IN_REVIEW'&&selected?.blockers.length>0)" @click="review"/></template>
  </Dialog>
  <Dialog :visible="thread!==null" modal header="Trao đổi về yêu cầu xóa tài khoản" :style="{width:'36rem',maxWidth:'95vw'}" @update:visible="v=>{if(!v&&!busy)thread=null}">
    <template v-if="thread"><div v-for="m in thread.messages" :key="m.id" class="privacy-request"><small>{{new Date(m.createdAt).toLocaleString('vi-VN')}}</small><p>{{m.body}}</p></div>
      <label v-if="thread.ticket.status!=='CLOSED'">Nội dung phản hồi<Textarea v-model="message" rows="4" :maxlength="5000" class="full-width" :disabled="busy"/></label>
      <Button v-if="thread.ticket.status!=='CLOSED'" label="Gửi phản hồi" :loading="busy" :disabled="!message.trim()" @click="reply"/>
    </template>
  </Dialog>
</template>
<style scoped>
.privacy-request{padding:20px 0;border-bottom:1px solid #edf1ee}.privacy-request p{line-height:1.7;white-space:pre-wrap;overflow-wrap:anywhere}.privacy-blocker{color:#986d33;background:#fff8eb;padding:8px 12px;border-radius:8px}.privacy-form{display:grid;gap:18px}.privacy-form label{display:grid;gap:8px}.muted,small{color:#7c8e82}
</style>
